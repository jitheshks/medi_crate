import 'package:flutter/foundation.dart';

import '../../../../core/utils/id_utils.dart';

/// HospitalModel represents a profile-scoped healthcare facility or clinic.
@immutable
class HospitalModel {
  final String id;
  final String profileId;
  final String name;
  final String? type;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final String? notes;
  final String? clientUuid;
  final DateTime? createdAt;

  const HospitalModel({
    required this.id,
    required this.profileId,
    required this.name,
    this.type,
    this.address,
    this.city,
    this.state,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.notes,
    this.clientUuid,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile_id': profileId,
    'name': name,
    'type': type,
    'address': address,
    'city': city,
    'state': state,
    'country': country,
    'phone': phone,
    'email': email,
    'website': website,
    'notes': notes,
    if (clientUuid != null) 'client_uuid': clientUuid,
    'created_at': createdAt?.toIso8601String(),
  };

  /// Serializes model to match the MediCrate REST API contract for POST /hospitals & POST /hospitals/{id} (H2 / H4)
  Map<String, dynamic> toApiJson() {
    final cleanProfileId =
        int.tryParse(IdUtils.unprefix(profileId)) ?? profileId;

    return {
      if (profileId.isNotEmpty) 'profile_id': cleanProfileId,
      'name': name.trim(),
      if (type != null && type!.trim().isNotEmpty) 'type': type!.trim(),
      if (address != null && address!.trim().isNotEmpty)
        'address': address!.trim(),
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      if (state != null && state!.trim().isNotEmpty) 'state': state!.trim(),
      if (country != null && country!.trim().isNotEmpty)
        'country': country!.trim(),
      if (phone != null && phone!.trim().isNotEmpty)
        'phone_number': phone!.trim(),
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (website != null && website!.trim().isNotEmpty)
        'website': website!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (clientUuid != null && clientUuid!.trim().isNotEmpty)
        'client_uuid': clientUuid!.trim(),
    };
  }

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    final cUuid =
        json['client_uuid']?.toString() ?? json['clientUuid']?.toString();

    final rawId = json['id'];
    String parsedId;
    if (rawId == null) {
      parsedId = cUuid ?? 'hospital_${DateTime.now().microsecondsSinceEpoch}';
    } else {
      final strId = rawId.toString();
      if (int.tryParse(strId) != null) {
        parsedId = 'hospital_$strId';
      } else {
        parsedId = strId;
      }
    }

    return HospitalModel(
      id: parsedId,
      profileId: json['profile_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Facility',
      type: json['type']?.toString() ?? json['facility_type']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      phone:
          json['phone_number']?.toString() ??
          json['phone']?.toString() ??
          json['emergency_phone']?.toString(),
      email: json['email']?.toString(),
      website: json['website']?.toString(),
      notes: json['notes']?.toString(),
      clientUuid: cUuid,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  HospitalModel copyWith({
    String? id,
    String? profileId,
    String? name,
    String? type,
    String? address,
    String? city,
    String? state,
    String? country,
    String? phone,
    String? email,
    String? website,
    String? notes,
    String? clientUuid,
    DateTime? createdAt,
  }) {
    return HospitalModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      clientUuid: clientUuid ?? this.clientUuid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HospitalModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          profileId == other.profileId &&
          name == other.name &&
          type == other.type &&
          address == other.address &&
          city == other.city &&
          state == other.state &&
          country == other.country &&
          phone == other.phone &&
          email == other.email &&
          website == other.website &&
          notes == other.notes &&
          clientUuid == other.clientUuid &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      profileId.hashCode ^
      name.hashCode ^
      type.hashCode ^
      address.hashCode ^
      city.hashCode ^
      state.hashCode ^
      country.hashCode ^
      phone.hashCode ^
      email.hashCode ^
      website.hashCode ^
      notes.hashCode ^
      clientUuid.hashCode ^
      createdAt.hashCode;
}
