import 'package:flutter/foundation.dart';

import '../../../../core/utils/id_utils.dart';

/// DoctorModel represents a profile-scoped doctor or specialist.
@immutable
class DoctorModel {
  final String id;
  final String profileId;
  final String name;
  final String specialty;
  final List<String> hospitalIds;
  final String? hospitalName;
  final String? phone;
  final String? email;
  final String? notes;
  final bool isFavorite;
  final String? clientUuid;
  final DateTime? createdAt;

  const DoctorModel({
    required this.id,
    required this.profileId,
    required this.name,
    required this.specialty,
    this.hospitalIds = const [],
    this.hospitalName,
    this.phone,
    this.email,
    this.notes,
    this.isFavorite = false,
    this.clientUuid,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile_id': profileId,
    'name': name,
    'specialty': specialty,
    'hospital_ids': hospitalIds,
    'hospital_name': hospitalName,
    'phone': phone,
    'email': email,
    'notes': notes,
    'is_favorite': isFavorite,
    if (clientUuid != null) 'client_uuid': clientUuid,
    'created_at': createdAt?.toIso8601String(),
  };

  /// Serializes model to match Supabase PostgREST table schema for `public.doctors`.
  Map<String, dynamic> toSupabaseJson({
    required String ownerUserId,
    required String profileId,
    bool includeId = true,
  }) {
    final cleanDocId = IdUtils.unprefix(id);
    final cleanProfileId = IdUtils.unprefix(profileId);

    final map = <String, dynamic>{
      'user_id': ownerUserId.trim(),
      'profile_id': cleanProfileId.trim(),
      'name': name.trim(),
      'specialty': specialty.trim(),
      if (hospitalName != null && hospitalName!.trim().isNotEmpty)
        'hospital_name': hospitalName!.trim(),
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      'is_favorite': isFavorite,
    };

    if (includeId && cleanDocId.isNotEmpty && UuidUtils.isValidUuid(cleanDocId)) {
      map['id'] = cleanDocId;
    }

    final cUuid = clientUuid?.trim();
    if (cUuid != null && cUuid.isNotEmpty && UuidUtils.isValidUuid(cUuid)) {
      map['client_uuid'] = cUuid;
    }

    return map;
  }

  /// Factory constructing a DoctorModel from Supabase PostgREST JSON row.
  factory DoctorModel.fromSupabaseJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final cUuid =
        json['client_uuid']?.toString() ?? json['clientUuid']?.toString();

    List<String> parsedHospitalIds = [];
    if (json['hospital_ids'] is List) {
      parsedHospitalIds = (json['hospital_ids'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['doctor_hospitals'] is List) {
      for (final rel in json['doctor_hospitals'] as List) {
        if (rel is Map && rel['hospital_id'] != null) {
          parsedHospitalIds.add(rel['hospital_id'].toString());
        }
      }
    }

    final rawFavorite = json['is_favorite'];
    final bool parsedIsFavorite = rawFavorite == true ||
        rawFavorite == 1 ||
        rawFavorite == 'true' ||
        rawFavorite == '1';

    return DoctorModel(
      id: rawId,
      profileId: json['profile_id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Dr. Unknown',
      specialty: json['specialty'] as String? ?? 'General Practice',
      hospitalIds: parsedHospitalIds,
      hospitalName: json['hospital_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      isFavorite: parsedIsFavorite,
      clientUuid: cUuid,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null),
    );
  }

  /// Serializes model to REST API compliant payload format (D2 / D4).
  Map<String, dynamic> toApiJson({String? resolvedHospitalName}) {
    final cleanProfileId =
        int.tryParse(IdUtils.unprefix(profileId)) ?? profileId;
    final cleanHospitalIds = hospitalIds
        .map((hId) => int.tryParse(IdUtils.unprefix(hId)))
        .whereType<int>()
        .toList();

    return {
      'profile_id': cleanProfileId,
      'name': name.trim(),
      'specialty': specialty.trim(),
      if (cleanHospitalIds.isNotEmpty) 'hospital_ids': cleanHospitalIds,
      if (resolvedHospitalName != null && resolvedHospitalName.isNotEmpty)
        'hospital_name': resolvedHospitalName
      else if (hospitalName != null && hospitalName!.isNotEmpty)
        'hospital_name': hospitalName,
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      'is_favorite': isFavorite,
      if (clientUuid != null && clientUuid!.trim().isNotEmpty)
        'client_uuid': clientUuid!.trim(),
    };
  }

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    final cUuid =
        json['client_uuid']?.toString() ?? json['clientUuid']?.toString();
    final rawId = json['id']?.toString() ?? '';

    List<String> parsedHospitalIds = [];
    if (json['hospital_ids'] is List) {
      parsedHospitalIds = (json['hospital_ids'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['hospitalIds'] is List) {
      parsedHospitalIds = (json['hospitalIds'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['doctor_hospitals'] is List) {
      for (final rel in json['doctor_hospitals'] as List) {
        if (rel is Map && rel['hospital_id'] != null) {
          parsedHospitalIds.add(rel['hospital_id'].toString());
        }
      }
    }

    return DoctorModel(
      id: rawId,
      profileId: json['profile_id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Dr. Unknown',
      specialty:
          json['specialty'] as String? ??
          json['specialisation'] as String? ??
          'General Practice',
      hospitalIds: parsedHospitalIds,
      hospitalName:
          json['hospital_name'] as String? ?? json['hospital'] as String?,
      phone: json['phone'] as String? ?? json['phone_number'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String? ?? json['clinical_notes'] as String?,
      isFavorite:
          json['is_favorite'] as bool? ?? json['isFavorite'] as bool? ?? false,
      clientUuid: cUuid,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['updated_at'] != null
                ? DateTime.tryParse(json['updated_at'].toString())
                : null),
    );
  }

  DoctorModel copyWith({
    String? id,
    String? profileId,
    String? name,
    String? specialty,
    List<String>? hospitalIds,
    String? hospitalName,
    String? phone,
    String? email,
    String? notes,
    bool? isFavorite,
    String? clientUuid,
    DateTime? createdAt,
  }) {
    return DoctorModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      hospitalIds: hospitalIds ?? this.hospitalIds,
      hospitalName: hospitalName ?? this.hospitalName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      clientUuid: clientUuid ?? this.clientUuid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoctorModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          profileId == other.profileId &&
          name == other.name &&
          specialty == other.specialty &&
          listEquals(hospitalIds, other.hospitalIds) &&
          hospitalName == other.hospitalName &&
          phone == other.phone &&
          email == other.email &&
          notes == other.notes &&
          isFavorite == other.isFavorite &&
          clientUuid == other.clientUuid &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      profileId.hashCode ^
      name.hashCode ^
      specialty.hashCode ^
      Object.hashAll(hospitalIds) ^
      hospitalName.hashCode ^
      phone.hashCode ^
      email.hashCode ^
      notes.hashCode ^
      isFavorite.hashCode ^
      clientUuid.hashCode ^
      createdAt.hashCode;
}
