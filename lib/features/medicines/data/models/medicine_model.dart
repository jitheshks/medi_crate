import 'package:flutter/foundation.dart';

@immutable
class MedicineModel {
  final String id;
  final String profileId;
  final String medicineName;
  final String dosage;
  final String? form;
  final String? frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool reminder;
  final List<String>? reminderTimes;
  final String? linkedConsultationId;
  final String? linkedConsultationTitle;
  final String? notes;
  final String? clientUuid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MedicineModel({
    required this.id,
    required this.profileId,
    required this.medicineName,
    required this.dosage,
    this.form,
    this.frequency,
    required this.startDate,
    this.endDate,
    this.reminder = true,
    this.reminderTimes,
    this.linkedConsultationId,
    this.linkedConsultationTitle,
    this.notes,
    this.clientUuid,
    this.createdAt,
    this.updatedAt,
  });

  /// Derived status — active if no end date or end date is in the future.
  bool get isActive => endDate == null || endDate!.isAfter(DateTime.now());

  /// Returns derived status string ('Active' or 'Completed').
  String get status => isActive ? 'Active' : 'Completed';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'medicine_name': medicineName,
      'medication_name': medicineName,
      'dosage': dosage,
      'form': form,
      'frequency': frequency,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'reminder': reminder,
      if (reminderTimes != null) 'reminder_times': reminderTimes,
      'is_active': isActive,
      'linked_consultation_id': linkedConsultationId,
      'linked_consultation_title': linkedConsultationTitle,
      'notes': notes,
      if (clientUuid != null) 'client_uuid': clientUuid,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// Serializes model to REST API compliant payload format (M2 / M4).
  Map<String, dynamic> toServerMetadataJson({int? serverProfileId}) => {
    'profile_id': serverProfileId ?? int.tryParse(profileId) ?? profileId,
    'medicine_name': medicineName,
    'dosage': dosage,
    if (form != null && form!.isNotEmpty) 'form': form,
    if (frequency != null && frequency!.isNotEmpty) 'frequency': frequency,
    'start_date': startDate.toIso8601String().split('T').first,
    if (endDate != null)
      'end_date': endDate!.toIso8601String().split('T').first,
    'reminder': reminder,
    if (reminderTimes != null && reminderTimes!.isNotEmpty)
      'reminder_times': reminderTimes,
    if (linkedConsultationId != null && linkedConsultationId!.isNotEmpty)
      'linked_consultation_id':
          int.tryParse(linkedConsultationId!) ?? linkedConsultationId,
    if (linkedConsultationTitle != null && linkedConsultationTitle!.isNotEmpty)
      'linked_consultation_title': linkedConsultationTitle,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (clientUuid != null && clientUuid!.isNotEmpty) 'client_uuid': clientUuid,
  };

  Map<String, dynamic> toApiJson({int? serverProfileId}) =>
      toServerMetadataJson(serverProfileId: serverProfileId);

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedStartDate;
    if (json['start_date'] != null) {
      parsedStartDate =
          DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now();
    } else {
      parsedStartDate = DateTime.now();
    }

    DateTime? parsedEndDate;
    if (json['end_date'] != null && json['end_date'].toString().isNotEmpty) {
      parsedEndDate = DateTime.tryParse(json['end_date'].toString());
    }

    DateTime? parsedCreatedAt;
    if (json['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['created_at'].toString());
    }

    DateTime? parsedUpdatedAt;
    if (json['updated_at'] != null) {
      parsedUpdatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    final name = (json['medicine_name'] ?? json['medication_name'] ?? '')
        .toString();
    final cUuid =
        json['client_uuid']?.toString() ?? json['clientUuid']?.toString();

    List<String>? parsedReminderTimes;
    if (json['reminder_times'] != null && json['reminder_times'] is List) {
      parsedReminderTimes = (json['reminder_times'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return MedicineModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      medicineName: name,
      dosage: json['dosage']?.toString() ?? '',
      form: json['form']?.toString(),
      frequency: json['frequency']?.toString(),
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      reminder: json['reminder'] as bool? ?? true,
      reminderTimes: parsedReminderTimes,
      linkedConsultationId: json['linked_consultation_id']?.toString(),
      linkedConsultationTitle: json['linked_consultation_title']?.toString(),
      notes: json['notes']?.toString(),
      clientUuid: cUuid,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  MedicineModel copyWith({
    String? id,
    String? profileId,
    String? medicineName,
    String? dosage,
    String? form,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? reminder,
    List<String>? reminderTimes,
    String? linkedConsultationId,
    String? linkedConsultationTitle,
    String? notes,
    String? clientUuid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      form: form ?? this.form,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminder: reminder ?? this.reminder,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      linkedConsultationId: linkedConsultationId ?? this.linkedConsultationId,
      linkedConsultationTitle:
          linkedConsultationTitle ?? this.linkedConsultationTitle,
      notes: notes ?? this.notes,
      clientUuid: clientUuid ?? this.clientUuid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
