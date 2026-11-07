import 'package:flutter/material.dart';
import '../../../../core/utils/id_utils.dart';
import 'consultation_attachment.dart';

/// ConsultationModel represents a profile-scoped clinical consultation record.
@immutable
class ConsultationModel {
  final String id;
  final String profileId;
  final String? appointmentId;
  final String? doctorId;
  final String doctorName;
  final String? doctorSpecialty;
  final String? hospitalId;
  final String? hospitalName;
  final String? departmentId;
  final String? department;
  final DateTime visitDate;
  final String? visitTime;
  final String chiefComplaint;
  final String diagnosis;
  final String? clinicalNotes;
  final bool isFollowUpRequired;
  final DateTime? followUpDate;
  final String? followUpTime;
  final bool followUpReminder;
  final String? followUpNotes;
  final bool isFollowUpDone;
  final String? followUpStatus;
  final List<String> tags;
  final double? consultationFee;
  final String currency;
  final List<ConsultationAttachment> attachments;
  final String? clientUuid;
  final DateTime createdAt;

  const ConsultationModel({
    required this.id,
    required this.profileId,
    this.appointmentId,
    this.doctorId,
    required this.doctorName,
    this.doctorSpecialty,
    this.hospitalId,
    this.hospitalName,
    this.departmentId,
    this.department,
    required this.visitDate,
    this.visitTime,
    required this.chiefComplaint,
    required this.diagnosis,
    this.clinicalNotes,
    this.isFollowUpRequired = false,
    this.followUpDate,
    this.followUpTime,
    this.followUpReminder = false,
    this.followUpNotes,
    this.isFollowUpDone = false,
    this.followUpStatus,
    this.tags = const [],
    this.consultationFee,
    this.currency = 'INR',
    this.attachments = const [],
    this.clientUuid,
    required this.createdAt,
  });

  /// Complete local persistence JSON representation for Hive cache storage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'profile_id': profileId,
    'appointment_id': appointmentId,
    'doctor_id': doctorId,
    'doctor_name': doctorName,
    'doctor_specialty': doctorSpecialty,
    'hospital_id': hospitalId,
    'hospital_name': hospitalName,
    'department_id': departmentId,
    'department': department,
    'visit_date': visitDate.toIso8601String(),
    'visit_time': visitTime,
    'chief_complaint': chiefComplaint,
    'diagnosis': diagnosis,
    'clinical_notes': clinicalNotes,
    'is_follow_up_required': isFollowUpRequired,
    'follow_up_date': followUpDate?.toIso8601String(),
    'follow_up_time': followUpTime,
    'follow_up_reminder': followUpReminder,
    'follow_up_notes': followUpNotes,
    'is_follow_up_done': isFollowUpDone,
    'follow_up_status':
        followUpStatus ?? (isFollowUpDone ? 'Completed' : 'Pending'),
    'tags': tags,
    'consultation_fee': consultationFee,
    'currency': currency,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    if (clientUuid != null) 'client_uuid': clientUuid,
    'created_at': createdAt.toIso8601String(),
  };

  /// Clean server metadata JSON representation for Laravel Sanctum REST API.
  /// Omits device-local file paths.
  Map<String, dynamic> toServerMetadataJson({int? serverProfileId}) {
    final cleanProfileId =
        serverProfileId ??
        IdUtils.toServerIntId(profileId) ??
        int.tryParse(IdUtils.unprefix(profileId));

    final cleanDoctorId = IdUtils.toServerIntId(doctorId);
    final cleanHospitalId = IdUtils.toServerIntId(hospitalId);
    final cleanDeptId = IdUtils.toServerIntId(departmentId);

    return {
      'profile_id': ?cleanProfileId,
      'doctor_name': doctorName,
      'visit_date': visitDate.toIso8601String().split('T').first,
      'chief_complaint': chiefComplaint,
      'diagnosis': diagnosis,
      'doctor_id': ?cleanDoctorId,
      if (doctorSpecialty != null && doctorSpecialty!.isNotEmpty)
        'doctor_specialty': doctorSpecialty,
      'hospital_id': ?cleanHospitalId,
      if (hospitalName != null && hospitalName!.isNotEmpty)
        'hospital_name': hospitalName,
      'department_id': ?cleanDeptId,
      if (department != null && department!.isNotEmpty)
        'department': department,
      if (visitTime != null && visitTime!.isNotEmpty) 'visit_time': visitTime,
      if (clinicalNotes != null && clinicalNotes!.isNotEmpty)
        'clinical_notes': clinicalNotes,
      'is_follow_up_required': isFollowUpRequired,
      if (isFollowUpRequired && followUpDate != null)
        'follow_up_date': followUpDate!.toIso8601String().split('T').first,
      if (isFollowUpRequired &&
          followUpTime != null &&
          followUpTime!.isNotEmpty)
        'follow_up_time': followUpTime,
      if (isFollowUpRequired) 'follow_up_reminder': followUpReminder,
      if (isFollowUpRequired &&
          followUpNotes != null &&
          followUpNotes!.isNotEmpty)
        'follow_up_notes': followUpNotes,
      if (isFollowUpRequired &&
          followUpStatus != null &&
          followUpStatus!.isNotEmpty)
        'follow_up_status': followUpStatus,
      if (tags.isNotEmpty) 'tags': tags,
      if (consultationFee != null) 'consultation_fee': consultationFee,
      'currency': currency,
      if (clientUuid != null && clientUuid!.trim().isNotEmpty)
        'client_uuid': clientUuid!.trim(),
    };
  }

  /// Alias for toServerMetadataJson() matching cross-module API serialization convention.
  Map<String, dynamic> toApiJson({int? serverProfileId}) =>
      toServerMetadataJson(serverProfileId: serverProfileId);

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    final isDone =
        json['is_follow_up_done'] as bool? ??
        (json['follow_up_status']?.toString().toLowerCase() == 'completed');

    List<ConsultationAttachment> parsedAttachments = const [];
    if (json['attachments'] != null && json['attachments'] is Iterable) {
      parsedAttachments = (json['attachments'] as Iterable)
          .whereType<Map>()
          .map(
            (a) =>
                ConsultationAttachment.fromJson(Map<String, dynamic>.from(a)),
          )
          .toList();
    }

    final cUuid =
        json['client_uuid']?.toString() ?? json['clientUuid']?.toString();
    final aptId =
        json['appointment_id']?.toString() ?? json['appointmentId']?.toString();

    return ConsultationModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      appointmentId: aptId,
      doctorId: json['doctor_id']?.toString(),
      doctorName: json['doctor_name']?.toString() ?? 'Dr. Practitioner',
      doctorSpecialty:
          json['doctor_specialty']?.toString() ?? json['specialty']?.toString(),
      hospitalId: json['hospital_id']?.toString(),
      hospitalName: json['hospital_name']?.toString(),
      departmentId: json['department_id']?.toString(),
      department:
          json['department']?.toString() ?? json['specialty']?.toString(),
      visitDate: json['visit_date'] != null
          ? DateTime.tryParse(json['visit_date'].toString()) ?? DateTime.now()
          : (json['consultation_date'] != null
                ? DateTime.tryParse(json['consultation_date'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      visitTime: json['visit_time']?.toString(),
      chiefComplaint:
          json['chief_complaint']?.toString() ??
          json['reason']?.toString() ??
          'Medical Consultation',
      diagnosis: json['diagnosis']?.toString() ?? 'General Health Assessment',
      clinicalNotes: json['clinical_notes']?.toString(),
      isFollowUpRequired:
          json['is_follow_up_required'] as bool? ??
          json['is_follow_up_needed'] as bool? ??
          false,
      followUpDate: json['follow_up_date'] != null
          ? DateTime.tryParse(json['follow_up_date'].toString())
          : null,
      followUpTime: json['follow_up_time']?.toString(),
      followUpReminder: json['follow_up_reminder'] as bool? ?? false,
      followUpNotes: json['follow_up_notes']?.toString(),
      isFollowUpDone: isDone,
      followUpStatus:
          json['follow_up_status']?.toString() ??
          (isDone ? 'Completed' : 'Pending'),
      tags: json['tags'] != null
          ? List<String>.from(
              (json['tags'] as Iterable).map((e) => e.toString()),
            )
          : const [],
      consultationFee: (json['consultation_fee'] as num?)?.toDouble(),
      currency: json['currency']?.toString() ?? 'INR',
      attachments: parsedAttachments,
      clientUuid: cUuid,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ConsultationModel copyWith({
    String? id,
    String? profileId,
    String? appointmentId,
    bool clearAppointmentId = false,
    String? doctorId,
    String? doctorName,
    String? doctorSpecialty,
    String? hospitalId,
    String? hospitalName,
    String? departmentId,
    String? department,
    DateTime? visitDate,
    String? visitTime,
    String? chiefComplaint,
    String? diagnosis,
    String? clinicalNotes,
    bool? isFollowUpRequired,
    DateTime? followUpDate,
    String? followUpTime,
    bool? followUpReminder,
    String? followUpNotes,
    bool? isFollowUpDone,
    String? followUpStatus,
    List<String>? tags,
    double? consultationFee,
    String? currency,
    List<ConsultationAttachment>? attachments,
    String? clientUuid,
    DateTime? createdAt,
  }) {
    return ConsultationModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      appointmentId: clearAppointmentId
          ? null
          : (appointmentId ?? this.appointmentId),
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      doctorSpecialty: doctorSpecialty ?? this.doctorSpecialty,
      hospitalId: hospitalId ?? this.hospitalId,
      hospitalName: hospitalName ?? this.hospitalName,
      departmentId: departmentId ?? this.departmentId,
      department: department ?? this.department,
      visitDate: visitDate ?? this.visitDate,
      visitTime: visitTime ?? this.visitTime,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      diagnosis: diagnosis ?? this.diagnosis,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      isFollowUpRequired: isFollowUpRequired ?? this.isFollowUpRequired,
      followUpDate: followUpDate ?? this.followUpDate,
      followUpTime: followUpTime ?? this.followUpTime,
      followUpReminder: followUpReminder ?? this.followUpReminder,
      followUpNotes: followUpNotes ?? this.followUpNotes,
      isFollowUpDone: isFollowUpDone ?? this.isFollowUpDone,
      followUpStatus: followUpStatus ?? this.followUpStatus,
      tags: tags ?? this.tags,
      consultationFee: consultationFee ?? this.consultationFee,
      currency: currency ?? this.currency,
      attachments: attachments ?? this.attachments,
      clientUuid: clientUuid ?? this.clientUuid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
