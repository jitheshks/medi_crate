import '../utils/id_utils.dart';
import 'models/sync_queue_item.dart';

/// The outcome of folding an incoming mutation into the existing sync queue.
///
/// [keysToDelete] are Hive keys of queue entries that are now fully superseded.
/// [putKey] / [putItem] is the single entry to write (null when the incoming
/// mutation cancels out an unsynced create — CASE B).
class CoalesceResult {
  const CoalesceResult({
    this.keysToDelete = const [],
    this.putKey,
    this.putItem,
  });

  final List<dynamic> keysToDelete;
  final dynamic putKey;
  final SyncQueueItem? putItem;

  bool get wroteSomething => putItem != null;
}

/// One existing queue entry: its Hive key and decoded item.
class QueueEntry {
  const QueueEntry(this.key, this.item);
  final dynamic key;
  final SyncQueueItem item;
}

/// Safe, offline-first mutation coalescing for the durable sync queue (P2-F4).
///
/// Rules (the queue only ever holds create / update / delete, and every payload
/// carries the entity's full current state):
///
///  * CASE A  create + update(s), not yet on server  -> one `create` with the
///            latest complete payload.
///  * CASE B  create + delete, server never saw it   -> nothing (both removed).
///  * CASE C  server create succeeded -> update       -> `update` on the server
///            id; never downgraded back to `create`.
///  * CASE D  server create succeeded -> delete       -> `delete` on the server
///            id (or a client_uuid-keyed deferred delete if the id is not known
///            locally yet).
///  * CASE E  update + update, already server-backed  -> latest `update` only.
///  * CASE F  a pending `delete` is never replaced by an update; a later
///            re-create is kept as its own entry.
///
/// Nothing is ever dropped unless the surviving entry provably represents the
/// required final server state. Entries that are currently being processed
/// (`syncing` with a fresh claim) are never mutated — the incoming mutation is
/// appended and folded on a later pass.
class QueueCoalescer {
  QueueCoalescer._();

  /// [existing] is the current queue. [incoming] is the new mutation.
  /// [hasServerRecord] / [resolvedServerId] come from a Hive lookup by
  /// client_uuid (the caller resolves them); they let CASE D work even when the
  /// incoming payload still carries a local id.
  static CoalesceResult coalesce({
    required List<QueueEntry> existing,
    required SyncQueueItem incoming,
    required DateTime now,
    required Duration leaseDuration,
    bool hasServerRecord = false,
    int? resolvedServerId,
  }) {
    final key = _logicalKey(incoming);

    // Legacy / un-keyable item (no client_uuid, no payload id): cannot be
    // matched to anything -> store as-is, collapse nothing.
    if (key == null) {
      return CoalesceResult(putKey: incoming.id, putItem: incoming);
    }

    final matches = <QueueEntry>[];
    for (final e in existing) {
      if (_logicalKey(e.item) != key) continue;
      if (!_profileCompatible(e.item, incoming)) continue;
      matches.add(e);
    }
    matches.sort((a, b) => a.item.createdAt.compareTo(b.item.createdAt));

    // Entries mid-flight in another processor: do not touch them.
    bool isFrozen(QueueEntry e) {
      if (e.item.status != 'syncing') return false;
      final at = e.item.claimedAt;
      if (at == null) return false;
      return now.difference(at) < leaseDuration;
    }

    final frozen = matches.where(isFrozen).toList();
    final stale = matches.where((e) => !isFrozen(e)).toList();

    if (frozen.isNotEmpty && stale.isEmpty) {
      // Something for this entity is being sent right now. Append the new
      // mutation untouched; the next pass folds it once the in-flight item
      // resolves. Never lose it, never disturb the running request.
      return CoalesceResult(putKey: incoming.id, putItem: incoming);
    }

    final reachedServer =
        hasServerRecord ||
        _reached(incoming) ||
        stale.any((e) => _reached(e.item)) ||
        resolvedServerId != null;

    final op = incoming.operation.toLowerCase();

    // ---- incoming: create / update ----------------------------------------
    if (op == 'create' || op == 'update') {
      final priorDelete = stale
          .where((e) => e.item.operation.toLowerCase() == 'delete')
          .toList();

      if (priorDelete.isNotEmpty) {
        // CASE F: keep the pending delete; keep the re-create as its own entry;
        // drop any other stale create/update entries.
        return CoalesceResult(
          keysToDelete: stale
              .where((e) => e.item.operation.toLowerCase() != 'delete')
              .map((e) => e.key)
              .toList(),
          putKey: incoming.id,
          putItem: incoming,
        );
      }

      final mergedOp = reachedServer ? 'update' : 'create';
      final mergedPayload = _withBestId(
        Map<String, dynamic>.from(incoming.payload),
        stale,
        resolvedServerId,
      );

      if (stale.isEmpty) {
        return CoalesceResult(
          putKey: incoming.id,
          putItem: incoming.copyWith(
            operation: mergedOp,
            payload: mergedPayload,
          ),
        );
      }

      // Fold onto the earliest stale entry: keep its Hive key + createdAt so
      // queue ordering is stable; reset the retry/claim state because this is a
      // fresh, complete user mutation.
      final target = stale.first;
      return CoalesceResult(
        keysToDelete: stale.skip(1).map((e) => e.key).toList(),
        putKey: target.key,
        putItem: target.item.copyWith(
          operation: mergedOp,
          payload: mergedPayload,
          status: 'pending',
          retryCount: 0,
          errorMessage: null,
          lastAttemptAt: null,
          claimToken: null,
          claimedAt: null,
        ),
      );
    }

    // ---- incoming: delete -------------------------------------------------
    final staleWrites = stale
        .where((e) => e.item.operation.toLowerCase() != 'delete')
        .toList();
    final staleDeletes = stale
        .where((e) => e.item.operation.toLowerCase() == 'delete')
        .toList();

    if (staleWrites.isEmpty) {
      if (staleDeletes.isNotEmpty) {
        // Idempotent: one delete survives.
        return CoalesceResult(
          keysToDelete: staleDeletes.skip(1).map((e) => e.key).toList(),
          putKey: staleDeletes.first.key,
          putItem: staleDeletes.first.item,
        );
      }
      // No prior create/update in the queue.
      if (_reached(incoming) || hasServerRecord || resolvedServerId != null) {
        return CoalesceResult(
          putKey: incoming.id,
          putItem: incoming.copyWith(
            payload: _deletePayload(incoming, stale, resolvedServerId),
          ),
        );
      }
      // Purely local entity that never reached the server -> nothing to do.
      return const CoalesceResult();
    }

    // There is a pending create/update for this entity.
    if (reachedServer) {
      // CASE D: server has (or is getting) this record -> delete by server id.
      final serverId = _bestServerId(stale, incoming, resolvedServerId);
      final payload = <String, dynamic>{
        'profile_id':
            incoming.payload['profile_id'] ??
            incoming.payload['profileId'] ??
            staleWrites.first.item.payload['profile_id'] ??
            staleWrites.first.item.payload['profileId'],
      };
      final uuid = _clientUuid(incoming) ?? _clientUuid(staleWrites.first.item);
      if (uuid != null) payload['client_uuid'] = uuid;
      if (serverId != null) {
        payload['id'] = serverId;
      } else {
        // Reached the server but the id is not known locally yet: keep the
        // delete keyed by client_uuid; the sync handler resolves + defers.
        payload['_needs_server_id'] = true;
      }
      return CoalesceResult(
        keysToDelete: stale.map((e) => e.key).toList(),
        putKey: incoming.id,
        putItem: incoming.copyWith(payload: payload),
      );
    }

    // CASE B: created and deleted entirely offline -> cancel everything.
    return CoalesceResult(keysToDelete: stale.map((e) => e.key).toList());
  }

  // ---------------------------------------------------------------------------

  static const _entityAliases = <String, String>{
    'doctor': 'doctor',
    'doctors': 'doctor',
    'hospital': 'hospital',
    'hospitals': 'hospital',
    'consultation': 'consultation',
    'consultations': 'consultation',
    'appointment': 'appointment',
    'appointments': 'appointment',
    'report': 'report',
    'reports': 'report',
    'medicine': 'medicine',
    'medicines': 'medicine',
    'measurement': 'vital',
    'measurements': 'vital',
    'vital': 'vital',
    'vitals': 'vital',
    'profile': 'profile',
    'profiles': 'profile',
    'family_member': 'profile',
    'family_members': 'profile',
  };

  static String _canonicalEntity(String entity) =>
      _entityAliases[entity.trim().toLowerCase()] ??
      entity.trim().toLowerCase();

  static String? _clientUuid(SyncQueueItem i) {
    final v = (i.payload['client_uuid'] ?? i.payload['clientUuid'])
        ?.toString()
        .trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Stable identity for a logical entity instance: entity + client_uuid, or
  /// entity + unprefixed payload id when no client_uuid exists. Returns null for
  /// legacy items that have neither (those never collapse).
  static String? _logicalKey(SyncQueueItem i) {
    final e = _canonicalEntity(i.entity);
    final uuid = _clientUuid(i);
    if (uuid != null) return '$e|u:$uuid';
    final pid = i.payload['id']?.toString().trim();
    if (pid != null && pid.isNotEmpty) return '$e|i:${IdUtils.unprefix(pid)}';
    return null;
  }

  /// Both items must not belong to concretely different profiles.
  static bool _profileCompatible(SyncQueueItem a, SyncQueueItem b) {
    final pa = (a.payload['profile_id'] ?? a.payload['profileId'])
        ?.toString()
        .trim();
    final pb = (b.payload['profile_id'] ?? b.payload['profileId'])
        ?.toString()
        .trim();
    if (pa == null || pa.isEmpty || pb == null || pb.isEmpty) return true;
    if (pa == pb) return true;
    if (IdUtils.matches(pa, pb)) return true;
    return IdUtils.unprefix(pa) == IdUtils.unprefix(pb);
  }

  static bool _reached(SyncQueueItem i) {
    if (IdUtils.toServerIntId(i.payload['id']) != null) return true;
    if (IdUtils.toServerIntId(i.payload['server_id']) != null) return true;
    if (IdUtils.toServerIntId(i.payload['server_profile_id']) != null) {
      return true;
    }
    return i.operation.toLowerCase() == 'update';
  }

  static int? _bestServerId(
    List<QueueEntry> stale,
    SyncQueueItem incoming,
    int? resolved,
  ) {
    if (resolved != null) return resolved;
    for (final e in [incoming, ...stale.map((s) => s.item)]) {
      final id =
          IdUtils.toServerIntId(e.payload['id']) ??
          IdUtils.toServerIntId(e.payload['server_id']) ??
          IdUtils.toServerIntId(e.payload['server_profile_id']);
      if (id != null) return id;
    }
    return null;
  }

  static Map<String, dynamic> _withBestId(
    Map<String, dynamic> payload,
    List<QueueEntry> stale,
    int? resolved,
  ) {
    if (IdUtils.toServerIntId(payload['id']) != null) return payload;
    final id = _bestServerId(
      stale,
      SyncQueueItem(
        id: '_',
        entity: '_',
        operation: 'update',
        payload: payload,
      ),
      resolved,
    );
    if (id != null) payload['id'] = id;
    return payload;
  }

  static Map<String, dynamic> _deletePayload(
    SyncQueueItem incoming,
    List<QueueEntry> stale,
    int? resolved,
  ) {
    final out = Map<String, dynamic>.from(incoming.payload);
    final id = _bestServerId(stale, incoming, resolved);
    if (id != null) out['id'] = id;
    return out;
  }
}
