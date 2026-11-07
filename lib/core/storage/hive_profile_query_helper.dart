import 'package:hive/hive.dart';
import '../utils/id_utils.dart';

/// Helper for querying entity records scoped to a specific profile from Hive [userBox].
class HiveProfileQueryHelper {
  HiveProfileQueryHelper._();

  /// Scans [userBox] for entries starting with [keyPrefix] belonging to [profileId].
  ///
  /// Preserves:
  /// - Exact iteration order of [userBox.keys].
  /// - Non-map value filtering (`val is Map`).
  /// - Field precedence: `profile_id` over `profileId`.
  /// - Complete profile ID matching & primary profile resolution via [IdUtils.matchesProfileId].
  /// - Read-only semantics (no Hive mutations, deletes, or modifications).
  static List<Map<String, dynamic>> getRecordsForProfile({
    required Box userBox,
    required String keyPrefix,
    required String profileId,
    Box? profileBox,
  }) {
    final records = <Map<String, dynamic>>[];

    for (final key in userBox.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        final val = userBox.get(key);
        if (val is Map) {
          final map = Map<String, dynamic>.from(val);
          final storedProfId =
              (map['profile_id'] ?? map['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            storedProfId,
            profileId,
            profileBox: profileBox,
          )) {
            records.add(map);
          }
        }
      }
    }

    return records;
  }
}
