/// ProfileRelationships defines standard relationship choices for family profiles.
abstract class ProfileRelationships {
  static const String self = 'Self';
  static const String father = 'Father';
  static const String mother = 'Mother';
  static const String spouse = 'Spouse';
  static const String son = 'Son';
  static const String daughter = 'Daughter';
  static const String brother = 'Brother';
  static const String sister = 'Sister';
  static const String grandfather = 'Grandfather';
  static const String grandmother = 'Grandmother';
  static const String guardian = 'Guardian';
  static const String other = 'Other';

  static const List<String> values = [
    self,
    father,
    mother,
    spouse,
    son,
    daughter,
    brother,
    sister,
    grandfather,
    grandmother,
    guardian,
    other,
  ];

  /// List of allowed relationships for adding/editing family sub-profiles.
  /// Note: 'Self' is reserved for the primary account profile and cannot be added as a family member.
  static const List<String> familyMemberValues = [
    father,
    mother,
    spouse,
    son,
    daughter,
    brother,
    sister,
    grandfather,
    grandmother,
    guardian,
    other,
  ];

  /// Normalizes any case/spacing variation of relationship string to standard TitleCase representation.
  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return self;
    final trimmed = raw.trim();
    for (final val in values) {
      if (val.toLowerCase() == trimmed.toLowerCase()) {
        return val;
      }
    }
    // If not matching known standard, capitalize first letter
    if (trimmed.isNotEmpty) {
      return trimmed[0].toUpperCase() + trimmed.substring(1);
    }
    return trimmed;
  }
}

/// ProfileModel represents a managed health profile owned by an authenticated User.
class ProfileModel {
  final String profileId;
  final int? serverProfileId;
  final String ownerUserId;
  final String fullName;
  final String relationship;
  final String? relationshipOther;
  final String? clientUuid;
  final String? gender;
  final String? dateOfBirth;
  final String? bloodGroup;
  final String? photo;
  final double? height;
  final double? weight;
  final bool isPrimary;
  final String? notes;
  final List<String> allergies;
  final bool allergiesConfirmedNone;
  final List<String> chronicConditions;
  final bool chronicConditionsConfirmedNone;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProfileModel({
    required this.profileId,
    this.serverProfileId,
    required this.ownerUserId,
    required this.fullName,
    required this.relationship,
    this.relationshipOther,
    this.clientUuid,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    this.photo,
    this.height,
    this.weight,
    this.isPrimary = false,
    this.notes,
    this.allergies = const [],
    this.allergiesConfirmedNone = false,
    this.chronicConditions = const [],
    this.chronicConditionsConfirmedNone = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Determines whether the profile belongs to an adult (18 years or older).
  /// Returns a clean, user-friendly relationship label for UI presentation.
  String get displayRelationship {
    if (isPrimary || relationship == ProfileRelationships.self) {
      return 'Primary';
    }
    if (relationship.toLowerCase() == 'other' &&
        relationshipOther != null &&
        relationshipOther!.trim().isNotEmpty) {
      return relationshipOther!.trim();
    }
    return relationship;
  }

  /// Determines whether the profile belongs to an adult (18 years or older).
  /// Defaults to true if dateOfBirth is omitted or unparseable.
  bool get isAdult {
    if (dateOfBirth == null || dateOfBirth!.trim().isEmpty) return true;
    final dob = _parseDate(dateOfBirth!);
    if (dob == null) return true;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  static DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;
    final match = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$')
        .firstMatch(trimmed);
    if (match != null) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final y = int.parse(match.group(3)!);
      return DateTime(y, m, d);
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'profile_id': profileId,
      if (serverProfileId != null) 'server_profile_id': serverProfileId,
      'owner_user_id': ownerUserId,
      'full_name': fullName,
      'relationship': relationship,
      'relationship_other': relationshipOther,
      'client_uuid': clientUuid,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'blood_group': bloodGroup,
      'photo': photo,
      'height': height,
      'weight': weight,
      'is_primary': isPrimary,
      'notes': notes,
      'allergies': allergies,
      'allergies_confirmed_none': allergiesConfirmedNone,
      'chronic_conditions': chronicConditions,
      'chronic_conditions_confirmed_none': chronicConditionsConfirmedNone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts model to payload for Laravel REST API (`/api/v1/family-members`).
  Map<String, dynamic> toApiJson() {
    final map = <String, dynamic>{
      'full_name': fullName,
      'relationship': ProfileRelationships.normalize(relationship),
    };

    if (clientUuid != null && clientUuid!.trim().isNotEmpty) {
      map['client_uuid'] = clientUuid!.trim();
    }

    if (relationship.toLowerCase() == 'other' &&
        relationshipOther != null &&
        relationshipOther!.trim().isNotEmpty) {
      map['relationship_other'] = relationshipOther!.trim();
    }

    if (gender != null && gender!.trim().isNotEmpty) {
      map['gender'] = gender!.trim().toLowerCase();
    }

    if (dateOfBirth != null && dateOfBirth!.trim().isNotEmpty) {
      map['date_of_birth'] = dateOfBirth!.trim();
    }

    if (bloodGroup != null && bloodGroup!.trim().isNotEmpty) {
      map['blood_group'] = bloodGroup!.trim();
    }

    if (height != null && height! > 0) {
      map['height'] = height!.toStringAsFixed(0);
    }

    if (weight != null && weight! > 0) {
      map['weight'] = weight!.toStringAsFixed(0);
    }

    if (notes != null && notes!.trim().isNotEmpty) {
      map['notes'] = notes!.trim();
    }

    if (allergies.isNotEmpty) {
      map['allergies'] = allergies;
    }

    if (chronicConditions.isNotEmpty) {
      map['chronic_conditions'] = chronicConditions;
    }

    return map;
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    // Height parsing (supports number or string)
    double? parsedHeight;
    final rawHeight = map['height'];
    if (rawHeight is num) {
      parsedHeight = rawHeight.toDouble();
    } else if (rawHeight is String && rawHeight.trim().isNotEmpty) {
      parsedHeight = double.tryParse(rawHeight.trim());
    }

    // Weight parsing (supports number or string)
    double? parsedWeight;
    final rawWeight = map['weight'];
    if (rawWeight is num) {
      parsedWeight = rawWeight.toDouble();
    } else if (rawWeight is String && rawWeight.trim().isNotEmpty) {
      parsedWeight = double.tryParse(rawWeight.trim());
    }

    // Is primary parsing (supports boolean, integer 1/0, string)
    final rawPrimary = map['is_primary'] ?? map['isPrimary'];
    final bool parsedIsPrimary =
        rawPrimary == true ||
        rawPrimary == 1 ||
        rawPrimary == '1' ||
        rawPrimary == 'true';

    // Allergies list parsing
    List<String> parsedAllergies = [];
    final rawAllergies = map['allergies'];
    if (rawAllergies is List) {
      parsedAllergies = rawAllergies.map((e) => e.toString()).toList();
    } else if (rawAllergies is String && rawAllergies.trim().isNotEmpty) {
      parsedAllergies = rawAllergies
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Chronic conditions list parsing
    List<String> parsedChronicConditions = [];
    final rawConditions = map['chronic_conditions'] ?? map['chronicConditions'];
    if (rawConditions is List) {
      parsedChronicConditions = rawConditions.map((e) => e.toString()).toList();
    } else if (rawConditions is String && rawConditions.trim().isNotEmpty) {
      parsedChronicConditions = rawConditions
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Profile ID
    final rawId = map['profile_id'] ?? map['id'] ?? '';
    final profileId = rawId.toString();

    // Server Profile ID resolution
    int? parsedServerProfileId;
    final rawServerId = map['server_profile_id'] ?? map['serverProfileId'];
    if (rawServerId is int && rawServerId > 0 && rawServerId < 1000000000000) {
      parsedServerProfileId = rawServerId;
    } else if (rawServerId != null) {
      final parsed = int.tryParse(rawServerId.toString());
      if (parsed != null && parsed > 0 && parsed < 1000000000000) {
        parsedServerProfileId = parsed;
      }
    }

    // Backward compatibility: If server_profile_id was not explicitly stored in Hive,
    // but the record has a clean numeric integer profileId (< 1,000,000,000,000), derive it.
    if (parsedServerProfileId == null && profileId.isNotEmpty) {
      if (!profileId.startsWith('prof_') && !profileId.startsWith('primary_')) {
        final parsed = int.tryParse(profileId);
        if (parsed != null && parsed > 0 && parsed < 1000000000000) {
          parsedServerProfileId = parsed;
        }
      }
    }

    // Owner user ID
    final rawOwner = map['owner_user_id'] ?? map['user_id'] ?? '';
    final ownerUserId = rawOwner.toString();

    // Photo URL or local path
    final rawPhoto = map['photo'] ?? map['photo_url'] ?? map['avatar'];

    final rawClientUuid = map['client_uuid'] ?? map['clientUuid'];

    return ProfileModel(
      profileId: profileId,
      serverProfileId: parsedServerProfileId,
      ownerUserId: ownerUserId,
      fullName: (map['full_name'] ?? map['name'] ?? 'Profile').toString(),
      relationship: ProfileRelationships.normalize(
        (map['relationship'] ?? ProfileRelationships.self).toString(),
      ),
      relationshipOther: map['relationship_other']?.toString(),
      clientUuid: rawClientUuid?.toString(),
      gender: map['gender']?.toString(),
      dateOfBirth: (map['date_of_birth'] ?? map['dateOfBirth'])?.toString(),
      bloodGroup: (map['blood_group'] ?? map['bloodGroup'])?.toString(),
      photo: rawPhoto?.toString(),
      height: parsedHeight,
      weight: parsedWeight,
      isPrimary: parsedIsPrimary,
      notes: map['notes']?.toString(),
      allergies: parsedAllergies,
      allergiesConfirmedNone:
          (map['allergies_confirmed_none'] ?? map['allergiesConfirmedNone'])
              as bool? ??
          false,
      chronicConditions: parsedChronicConditions,
      chronicConditionsConfirmedNone:
          (map['chronic_conditions_confirmed_none'] ??
                  map['chronicConditionsConfirmedNone'])
              as bool? ??
          false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ProfileModel copyWith({
    String? profileId,
    int? serverProfileId,
    bool clearServerProfileId = false,
    String? ownerUserId,
    String? fullName,
    String? relationship,
    String? relationshipOther,
    String? clientUuid,
    String? gender,
    String? dateOfBirth,
    String? bloodGroup,
    String? photo,
    double? height,
    double? weight,
    bool? isPrimary,
    String? notes,
    List<String>? allergies,
    bool? allergiesConfirmedNone,
    List<String>? chronicConditions,
    bool? chronicConditionsConfirmedNone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      profileId: profileId ?? this.profileId,
      serverProfileId: clearServerProfileId
          ? null
          : (serverProfileId ?? this.serverProfileId),
      ownerUserId: ownerUserId ?? this.ownerUserId,
      fullName: fullName ?? this.fullName,
      relationship: relationship ?? this.relationship,
      relationshipOther: relationshipOther ?? this.relationshipOther,
      clientUuid: clientUuid ?? this.clientUuid,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      photo: photo ?? this.photo,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      isPrimary: isPrimary ?? this.isPrimary,
      notes: notes ?? this.notes,
      allergies: allergies ?? this.allergies,
      allergiesConfirmedNone:
          allergiesConfirmedNone ?? this.allergiesConfirmedNone,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      chronicConditionsConfirmedNone:
          chronicConditionsConfirmedNone ?? this.chronicConditionsConfirmedNone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
