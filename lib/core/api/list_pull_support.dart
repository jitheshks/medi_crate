/// Shared helper for Server -> Hive list pulls (D1/H1/C1/AP1/R1/M1/V1).
///
/// The authoritative MediVault API documentation (`MediVault_API_Documentation_v1`)
/// exposes only a `limit` query parameter for these seven clinical list
/// endpoints (no `page`/`offset`/`cursor` — only `/timeline` documents `page`)
/// and reports the full dataset size in the `data.total` envelope field.
///
/// [reportListTotal] additionally tolerates a Laravel-style paginator envelope
/// (`meta.total` / `pagination.total`) IF the deployed backend happens to return
/// one — this is purely defensive response parsing; no request parameter is
/// assumed or invented. Remote data sources forward the resolved value to the
/// repository via an `onTotal` callback so the repository can decide whether a
/// second, `limit == total` request is required for a complete pull.
library;

import 'api_constants.dart';

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v == null) return null;
  return int.tryParse(v.toString());
}

int? _resolveTotal(dynamic source) {
  final direct = _asInt(source);
  if (direct != null) return direct;
  if (source is Map) {
    final field = _asInt(
      source['total'] ?? source['total_count'] ?? source['count'],
    );
    if (field != null) return field;
    final meta = source['meta'];
    if (meta is Map) {
      final m = _asInt(meta['total'] ?? meta['total_count']);
      if (m != null) return m;
    }
    final pagination = source['pagination'];
    if (pagination is Map) {
      final p = _asInt(pagination['total'] ?? pagination['total_count']);
      if (p != null) return p;
    }
  }
  return null;
}

/// Deep value-equality for decoded JSON (nested maps / lists / scalars),
/// order-insensitive for maps. Dependency-free.
bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Top-level keys ignored when deciding whether a pulled record changed. Several
/// models emit `(field ?? DateTime.now())` from `toJson()`, so a byte-identical
/// server record still serialises to a fresh timestamp on every pull. Comparing
/// on those would make every pull look like a change and feed the freshness
/// signal back into another pull. Freshness is about content, not sync clocks.
const Set<String> _volatilePullKeys = {
  'updated_at',
  'updatedat',
  'created_at',
  'createdat',
  'synced_at',
  'syncedat',
  'last_synced_at',
  'lastsyncedat',
  'server_synced_at',
  '_rev',
  'rev',
};

Map<String, dynamic> _stableSubset(Map<dynamic, dynamic> input) {
  final out = <String, dynamic>{};
  input.forEach((k, v) {
    if (v == null) return;
    final key = k.toString();
    if (_volatilePullKeys.contains(key.toLowerCase())) return;
    out[key] = v;
  });
  return out;
}

/// Whether merging [incoming] over [existing] (the current Hive value for the
/// same key) actually changes local content. A missing / non-map [existing]
/// always counts as a change; volatile sync timestamps are ignored. Repository
/// pulls use this to decide whether to raise the post-pull freshness signal — a
/// steady-state pull that returns identical data changes nothing and therefore
/// emits no signal, which is what keeps the signal from feeding back into
/// another pull (Phase 3).
bool pulledRecordChanged(Object? existing, Map<String, dynamic> incoming) {
  if (existing is! Map) return true;
  return !_deepEquals(_stableSubset(existing), _stableSubset(incoming));
}

/// Passes the dataset total to [onTotal]. [source] may be the `total` value
/// itself (int / numeric string) or the whole `data` envelope map (from which
/// `total`, `meta.total` or `pagination.total` is extracted). No-op when
/// [onTotal] is null or no total can be resolved.
void reportListTotal(dynamic source, void Function(int total)? onTotal) {
  if (onTotal == null || source == null) return;
  final resolved = _resolveTotal(source);
  if (resolved != null) onTotal(resolved);
}

/// Retrieves a complete profile-scoped list from a `limit`-only list endpoint.
///
/// [fetchPage] must issue ONE request for the supplied `limit`, forwarding the
/// server's dataset total to the given `onTotal` callback. This helper:
///   1. requests [batchLimit] rows,
///   2. if `total` exceeds what came back (and exceeds [batchLimit]), issues a
///      single follow-up request with `limit == total`.
///
/// Bounded to at most two requests; always terminates. Returns the fullest list
/// obtained.
///
/// [onComplete] receives `true` ONLY when completeness is actually proven:
///   * the server reported a `total` and `received >= total`, or
///   * the server reported no `total` but returned fewer rows than [batchLimit]
///     (it ran out of data).
/// A full batch with no `total` is NOT provably complete -> `false` (the caller
/// must treat the pull as partial: upsert only, never delete).
Future<List<Map<String, dynamic>>> fetchCompleteList(
  Future<List<Map<String, dynamic>>> Function(
    int limit,
    void Function(int total) onTotal,
  )
  fetchPage, {
  int batchLimit = ApiConstants.syncPullBatchLimit,
  void Function(bool complete)? onComplete,
}) async {
  int? total;
  var rows = await fetchPage(batchLimit, (t) => total = t);

  if (total != null && total! > rows.length && total! > batchLimit) {
    final full = await fetchPage(total!, (t) => total = t);
    if (full.length >= rows.length) rows = full;
  }

  final bool complete;
  if (total != null) {
    complete = rows.length >= total!;
  } else {
    complete = rows.length < batchLimit;
  }
  onComplete?.call(complete);
  return rows;
}
