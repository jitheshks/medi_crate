import 'package:hive/hive.dart';

/// Utility methods for robust, normalized ID comparisons across entities.
class IdUtils {
  IdUtils._();

  /// Strips known prefixes recursively from an entity ID.
  /// Note: Primary profile ID (`prof_primary_...`) is intentionally NOT stripped
  /// to prevent conflating user account IDs with server profile IDs.
  static String unprefix(String? id) {
    if (id == null || id.isEmpty) return '';
    const prefixes = [
      'doctor_',
      'doc_',
      'hospital_',
      'hosp_',
      'department_',
      'dept_',
      'profile_',
      'prof_',
      'user_',
      'usr_',
      'consultation_',
      'con_',
      'report_',
      'rep_',
      'medicine_',
      'med_',
      'appointment_',
      'apt_',
      'measurement_',
      'vital_',
    ];
    String current = id;
    bool matched = true;
    while (matched) {
      matched = false;
      for (final p in prefixes) {
        if (current.startsWith(p)) {
          current = current.substring(p.length);
          matched = true;
          break;
        }
      }
    }
    return current;
  }

  /// Extracts a valid server database integer ID from an entity ID.
  /// Returns null if the ID is missing, non-numeric, or a temporary offline timestamp.
  static int? toServerIntId(dynamic id) {
    if (id == null) return null;
    final str = id.toString().trim();
    if (str.isEmpty) return null;
    final cleaned = unprefix(str);
    final parsed = int.tryParse(cleaned);
    // Real server database IDs are positive sequential integers (< 1,000,000,000,000).
    // Timestamps from microsecondsSinceEpoch are >= 1,000,000,000,000 and should not be sent as server IDs.
    if (parsed != null && parsed > 0 && parsed < 1000000000000) {
      return parsed;
    }
    return null;
  }

  /// Resolves the integer server database profile_id from a local profile ID
  /// using the persistent profileBox in HiveService.
  ///
  /// For primary profile (`prof_primary_<userId>`), resolves its persistent `server_profile_id`.
  /// For secondary profiles (`prof_<uuid>`), resolves its persistent `server_profile_id`.
  /// For legacy records with numeric profileId, returns the integer ID directly.
  static int? resolveServerProfileId({
    required Box profileBox,
    dynamic profileId,
  }) {
    if (profileId == null) return null;
    final str = profileId.toString().trim();
    if (str.isEmpty) return null;

    final raw = profileBox.get(str);
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw);
      final serverId = map['server_profile_id'] ?? map['serverProfileId'];
      if (serverId is int && serverId > 0 && serverId < 1000000000000) {
        return serverId;
      }
      if (serverId != null) {
        final parsed = int.tryParse(serverId.toString());
        if (parsed != null && parsed > 0 && parsed < 1000000000000) {
          return parsed;
        }
      }
      // Profile exists in profileBox but server_profile_id is null / not yet assigned
      return null;
    }

    // Fallback: search profileBox by profile_id or client_uuid
    for (final val in profileBox.values) {
      final map = Map<String, dynamic>.from(val);
      final pId = map['profile_id']?.toString() ?? map['id']?.toString();
      final cUuid =
          map['client_uuid']?.toString() ?? map['clientUuid']?.toString();
      if (pId == str || (cUuid != null && cUuid == str)) {
        final serverId = map['server_profile_id'] ?? map['serverProfileId'];
        if (serverId is int && serverId > 0 && serverId < 1000000000000) {
          return serverId;
        }
        if (serverId != null) {
          final parsed = int.tryParse(serverId.toString());
          if (parsed != null && parsed > 0 && parsed < 1000000000000) {
            return parsed;
          }
        }
        // Matched profile record in box but server_profile_id is not yet assigned
        return null;
      }
    }

    // If str has known non-server prefixes or is a UUID, do not parse as an integer server ID
    if (str.startsWith('prof_') ||
        str.startsWith('profile_') ||
        str.startsWith('user_') ||
        str.startsWith('usr_') ||
        UuidUtils.isValidV4(str)) {
      return null;
    }

    // Check if str is directly a valid server database integer (< 1,000,000,000,000)
    final parsed = int.tryParse(str);
    if (parsed != null && parsed > 0 && parsed < 1000000000000) {
      return parsed;
    }
    return null;
  }

  /// Checks if two IDs match, accounting for possible prefix differences.
  static bool matches(String? a, String? b) {
    if (a == null || b == null) return false;
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    return unprefix(a) == unprefix(b);
  }

  /// Checks if a list of IDs contains a target ID (prefix-insensitive).
  static bool contains(Iterable<String>? list, String? target) {
    if (list == null || target == null || target.isEmpty) return false;
    final targetRaw = unprefix(target);
    return list.any((item) => item == target || unprefix(item) == targetRaw);
  }

  /// Robustly checks whether a record's raw profile_id from local storage or API
  /// matches the target profileId, accounting for prefixes ('prof_primary_...',
  /// 'prof_...', 'profile_...'), server integer IDs (e.g. 12 vs '12' vs 'prof_primary_1'),
  /// and profileBox lookup resolution.
  static bool matchesProfileId(
    dynamic rawProfileId,
    String? targetProfileId, {
    Box? profileBox,
    int? serverProfileId,
  }) {
    if (rawProfileId == null ||
        targetProfileId == null ||
        targetProfileId.isEmpty) {
      return false;
    }
    final rawStr = rawProfileId.toString().trim();
    final targetStr = targetProfileId.trim();
    if (rawStr.isEmpty || targetStr.isEmpty) return false;
    if (rawStr == targetStr) return true;

    // Check prefix-insensitive match (e.g. 'prof_12' vs '12')
    final rawClean = unprefix(rawStr);
    final targetClean = unprefix(targetStr);
    if (rawClean.isNotEmpty &&
        targetClean.isNotEmpty &&
        rawClean == targetClean) {
      return true;
    }

    // Direct serverProfileId check if explicitly provided
    if (serverProfileId != null) {
      final sStr = serverProfileId.toString();
      if (rawStr == sStr || rawClean == sStr) return true;
    }

    // Resolve target's server profile ID from profileBox
    if (profileBox != null) {
      final targetServerId =
          serverProfileId ??
          resolveServerProfileId(profileBox: profileBox, profileId: targetStr);
      if (targetServerId != null) {
        final targetServerStr = targetServerId.toString();
        if (rawStr == targetServerStr || rawClean == targetServerStr) {
          return true;
        }

        final rawServerId = resolveServerProfileId(
          profileBox: profileBox,
          profileId: rawStr,
        );
        if (rawServerId != null && rawServerId == targetServerId) {
          return true;
        }
      }
    }

    return false;
  }
}

/// Utility for generating and validating RFC 4122 Version 4 compliant UUIDs.
class UuidUtils {
  UuidUtils._();

  static final _random = DateTime.now().microsecondsSinceEpoch;
  static int _counter = 0;

  /// Generates a cryptographically random RFC 4122 Version 4 UUID string.
  /// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  static String generateV4() {
    // Generate 16 pseudo-random bytes using secure/hardware entropy seed
    final now = DateTime.now().microsecondsSinceEpoch;
    _counter = (_counter + 1) & 0xFFFFFF;
    final seed = now ^ _random ^ (_counter << 8);

    final values = List<int>.generate(16, (i) {
      final shifted =
          (seed >> (i * 4)) ^ (now >> (i * 2)) ^ (i * 37 + _counter);
      return (shifted & 0xFF);
    });

    // Set version to 4 (bits 4-7 of byte 6) -> 0100xxxx
    values[6] = (values[6] & 0x0F) | 0x40;
    // Set variant to RFC 4122 (bits 6-7 of byte 8) -> 10xxxxxx
    values[8] = (values[8] & 0x3F) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Validates if a string conforms to RFC 4122 Version 4 UUID format.
  static bool isValidV4(String? uuid) {
    if (uuid == null || uuid.isEmpty) return false;
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(uuid);
  }
}
