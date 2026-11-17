/// Shared helper for Server -> Hive cache diffing.
///
/// Decides whether merging [incoming] over [existing] (the current Hive value
/// for the same key) actually changes local content. Volatile sync timestamps
/// and revision metadata are ignored so timestamp churn does not falsely
/// trigger repository pull freshness signals.
library;

/// Top-level keys ignored when deciding whether a pulled record changed.
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

/// Whether merging [incoming] over [existing] (the current Hive value for the
/// same key) actually changes local content. A missing / non-map [existing]
/// always counts as a change; volatile sync timestamps are ignored.
bool pulledRecordChanged(Object? existing, Map<String, dynamic> incoming) {
  if (existing is! Map) return true;
  return !_deepEquals(_stableSubset(existing), _stableSubset(incoming));
}
