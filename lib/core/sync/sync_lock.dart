import 'package:hive/hive.dart';

/// Best-effort cross-context mutual exclusion for [SyncService.syncPending].
///
/// The foreground app and the WorkManager background isolate each construct
/// their own [SyncService], so the instance-level `_isSyncing` flag does not
/// coordinate them. This lease lock — persisted in the Hive settings box —
/// lets one processor claim the sync queue for a bounded window. A lease left
/// behind by a crashed holder auto-expires, so synchronization can never be
/// permanently blocked.
///
/// This is local app-level coordination, not a server or OS lock.
class SyncLock {
  SyncLock(this._box);

  final Box<Map> _box;

  static const String _key = '__sync_lease__';

  /// Fail-open sentinel returned when the lock store itself is unavailable;
  /// callers proceed (never block sync) and [release] is then a no-op.
  static const String noLockToken = '__nolock__';

  /// How long a claim is honoured before it is treated as abandoned.
  static const Duration leaseDuration = Duration(minutes: 3);

  /// Attempts to claim the lease.
  ///
  /// Returns an opaque token on success, [noLockToken] if the lock store is
  /// unavailable (fail open), or `null` if another processor holds a lease that
  /// has not yet expired.
  Future<String?> tryAcquire() async {
    try {
      final now = DateTime.now();
      final existing = _box.get(_key);
      if (existing is Map) {
        final expiresAt = DateTime.tryParse(
          existing['expiresAt']?.toString() ?? '',
        );
        if (expiresAt != null && expiresAt.isAfter(now)) {
          return null; // held and still valid
        }
        // Stale / expired lease -> reclaim below.
      }
      final token = 'lease_${now.microsecondsSinceEpoch}';
      await _box.put(_key, {
        'token': token,
        'acquiredAt': now.toIso8601String(),
        'expiresAt': now.add(leaseDuration).toIso8601String(),
      });
      return token;
    } catch (_) {
      return noLockToken;
    }
  }

  /// Renews an active lease held by [token], extending it by [leaseDuration].
  Future<bool> renew(String token) async {
    if (token == noLockToken) return true;
    try {
      final now = DateTime.now();
      final existing = _box.get(_key);
      if (existing is Map && existing['token']?.toString() == token) {
        await _box.put(_key, {
          'token': token,
          'acquiredAt': existing['acquiredAt'] ?? now.toIso8601String(),
          'expiresAt': now.add(leaseDuration).toIso8601String(),
        });
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Releases the lease if [token] still owns it. Safe to call unconditionally.
  Future<void> release(String token) async {
    if (token == noLockToken) return;
    try {
      final existing = _box.get(_key);
      if (existing is Map && existing['token']?.toString() == token) {
        await _box.delete(_key);
      }
    } catch (_) {
      // Ignore: a stale lease will expire on its own.
    }
  }
}
