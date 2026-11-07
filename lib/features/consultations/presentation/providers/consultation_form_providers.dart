import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import '../../../../core/providers/mutable_state_notifier.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../../../doctors/presentation/providers/doctors_providers.dart';
import '../../../hospitals/presentation/providers/hospitals_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/consultation_attachment.dart';
import '../../data/models/consultation_model.dart';
import 'consultation_providers.dart';

import '../../../settings/presentation/providers/settings_providers.dart';

// Form state providers for New/Edit Consultation
final selectedDoctorProvider = mutableStateProvider<String?>(null);
final selectedDoctorIdProvider = mutableStateProvider<String?>(null);
final selectedDoctorSpecialtyProvider =
    mutableStateProvider<String?>(null);
final selectedHospitalProvider = mutableStateProvider<String?>(null);
final selectedHospitalIdProvider = mutableStateProvider<String?>(null);
final selectedDepartmentProvider = mutableStateProvider<String?>(null);
final selectedDepartmentIdProvider =
    mutableStateProvider<String?>(null);
final selectedAppointmentIdProvider =
    mutableStateProvider<String?>(null);
final visitDateProvider =
    mutableStateProvider<DateTime>(DateTime.now());
final visitTimeProvider =
    mutableStateProvider<TimeOfDay>(TimeOfDay.now());
final isFollowUpEnabledProvider = mutableStateProvider<bool>(false);
final followUpDateProvider = mutableStateProvider<DateTime?>(null);
final followUpTimeProvider = mutableStateProvider<TimeOfDay?>(null);
final followUpReminderProvider = mutableStateProvider<bool>(true);
final selectedCurrencyProvider = mutableStateProvider<String?>(null);
final consultationAttachmentsProvider =
    mutableStateProvider<List<ConsultationAttachment>>(const []);

/// Signature of a Riverpod provider reader function (shared by WidgetRef and ProviderContainer).
typedef ProviderReader = T Function<T>(ProviderListenable<T>);

/// Resets all temporary form providers for New Consultation using a [WidgetRef].
void resetConsultationForm(WidgetRef ref) => _resetConsultationForm(ref.read);

/// Resets all temporary form providers for New Consultation using a [ProviderContainer].
void resetConsultationFormContainer(ProviderContainer container) {
  try {
    _resetConsultationForm(container.read);
  } catch (_) {}
}

void _resetConsultationForm(ProviderReader read) {
  read(selectedDoctorProvider.notifier).state = null;
  read(selectedDoctorIdProvider.notifier).state = null;
  read(selectedDoctorSpecialtyProvider.notifier).state = null;
  read(selectedHospitalProvider.notifier).state = null;
  read(selectedHospitalIdProvider.notifier).state = null;
  read(selectedDepartmentProvider.notifier).state = null;
  read(selectedDepartmentIdProvider.notifier).state = null;
  read(selectedAppointmentIdProvider.notifier).state = null;
  read(visitDateProvider.notifier).state = DateTime.now();
  read(visitTimeProvider.notifier).state = TimeOfDay.now();
  read(isFollowUpEnabledProvider.notifier).state = false;
  read(followUpDateProvider.notifier).state = null;
  read(followUpTimeProvider.notifier).state = null;
  read(followUpReminderProvider.notifier).state = true;
  read(selectedCurrencyProvider.notifier).state = null;
  read(consultationAttachmentsProvider.notifier).state =
      const <ConsultationAttachment>[];
}

/// Helper function saving consultation record with attachments and updating dependent providers using WidgetRef.
Future<void> saveConsultationRecord({
  required WidgetRef ref,
  required String doctorName,
  String? doctorId,
  String? doctorSpecialty,
  String? hospitalName,
  String? hospitalId,
  String? departmentId,
  String? department,
  String? appointmentId,
  required DateTime visitDate,
  TimeOfDay? visitTime,
  required String chiefComplaint,
  required String diagnosis,
  String? clinicalNotes,
  required bool isFollowUpRequired,
  DateTime? followUpDate,
  TimeOfDay? followUpTime,
  bool followUpReminder = false,
  String? followUpNotes,
  List<String> tags = const [],
  double? consultationFee,
  String? currency,
  List<ConsultationAttachment> attachments = const [],
  String? consultationIdToEdit,
  String? clientUuid,
}) => _saveConsultationRecord(
  read: ref.read,
  doctorName: doctorName,
  doctorId: doctorId,
  doctorSpecialty: doctorSpecialty,
  hospitalName: hospitalName,
  hospitalId: hospitalId,
  departmentId: departmentId,
  department: department,
  appointmentId: appointmentId,
  visitDate: visitDate,
  visitTime: visitTime,
  chiefComplaint: chiefComplaint,
  diagnosis: diagnosis,
  clinicalNotes: clinicalNotes,
  isFollowUpRequired: isFollowUpRequired,
  followUpDate: followUpDate,
  followUpTime: followUpTime,
  followUpReminder: followUpReminder,
  followUpNotes: followUpNotes,
  tags: tags,
  consultationFee: consultationFee,
  currency: currency,
  attachments: attachments,
  consultationIdToEdit: consultationIdToEdit,
  clientUuid: clientUuid,
);

/// Helper function saving consultation record with attachments and updating dependent providers using ProviderContainer.
Future<void> saveConsultationRecordContainer({
  required ProviderContainer container,
  required String doctorName,
  String? doctorId,
  String? doctorSpecialty,
  String? hospitalName,
  String? hospitalId,
  String? departmentId,
  String? department,
  String? appointmentId,
  required DateTime visitDate,
  TimeOfDay? visitTime,
  required String chiefComplaint,
  required String diagnosis,
  String? clinicalNotes,
  required bool isFollowUpRequired,
  DateTime? followUpDate,
  TimeOfDay? followUpTime,
  bool followUpReminder = false,
  String? followUpNotes,
  List<String> tags = const [],
  double? consultationFee,
  String? currency,
  List<ConsultationAttachment> attachments = const [],
  String? consultationIdToEdit,
  String? clientUuid,
}) => _saveConsultationRecord(
  read: container.read,
  doctorName: doctorName,
  doctorId: doctorId,
  doctorSpecialty: doctorSpecialty,
  hospitalName: hospitalName,
  hospitalId: hospitalId,
  departmentId: departmentId,
  department: department,
  appointmentId: appointmentId,
  visitDate: visitDate,
  visitTime: visitTime,
  chiefComplaint: chiefComplaint,
  diagnosis: diagnosis,
  clinicalNotes: clinicalNotes,
  isFollowUpRequired: isFollowUpRequired,
  followUpDate: followUpDate,
  followUpTime: followUpTime,
  followUpReminder: followUpReminder,
  followUpNotes: followUpNotes,
  tags: tags,
  consultationFee: consultationFee,
  currency: currency,
  attachments: attachments,
  consultationIdToEdit: consultationIdToEdit,
  clientUuid: clientUuid,
);

Future<void> _saveConsultationRecord({
  required ProviderReader read,
  required String doctorName,
  String? doctorId,
  String? doctorSpecialty,
  String? hospitalName,
  String? hospitalId,
  String? departmentId,
  String? department,
  String? appointmentId,
  required DateTime visitDate,
  TimeOfDay? visitTime,
  required String chiefComplaint,
  required String diagnosis,
  String? clinicalNotes,
  required bool isFollowUpRequired,
  DateTime? followUpDate,
  TimeOfDay? followUpTime,
  bool followUpReminder = false,
  String? followUpNotes,
  List<String> tags = const [],
  double? consultationFee,
  String? currency,
  List<ConsultationAttachment> attachments = const [],
  String? consultationIdToEdit,
  String? clientUuid,
}) async {
  final activeProfile = read(activeProfileProvider);
  if (activeProfile == null) {
    throw Exception('No active profile selected.');
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final visitDateOnly = DateTime(
    visitDate.year,
    visitDate.month,
    visitDate.day,
  );
  if (visitDateOnly.isAfter(today)) {
    throw const ValidationException(
      'Consultation visit date cannot be in the future.',
    );
  }

  final visitDateTime = DateTime(
    visitDate.year,
    visitDate.month,
    visitDate.day,
    visitTime?.hour ?? 0,
    visitTime?.minute ?? 0,
  );

  final formattedTime = visitTime != null
      ? '${visitTime.hour.toString().padLeft(2, '0')}:${visitTime.minute.toString().padLeft(2, '0')}'
      : null;

  final formattedFollowUpTime = followUpTime != null
      ? '${followUpTime.hour.toString().padLeft(2, '0')}:${followUpTime.minute.toString().padLeft(2, '0')}'
      : null;

  final id =
      consultationIdToEdit ??
      'consultation_${DateTime.now().microsecondsSinceEpoch}';

  // Resolve Doctor entity ID and specialty if not explicitly passed
  String? resolvedDoctorId = doctorId ?? read(selectedDoctorIdProvider);
  String? resolvedSpecialty =
      doctorSpecialty ?? read(selectedDoctorSpecialtyProvider);
  final cleanDocName = doctorName.contains('(')
      ? doctorName.split('(')[0].trim()
      : doctorName.trim();

  if (resolvedDoctorId == null || resolvedDoctorId.isEmpty) {
    try {
      final docRepo = read(doctorRepositoryProvider);
      final docs = await docRepo.getDoctorModels(activeProfile.profileId);
      final matchingDoc = docs
          .where(
            (d) => d.name.trim().toLowerCase() == cleanDocName.toLowerCase(),
          )
          .firstOrNull;
      if (matchingDoc != null) {
        resolvedDoctorId ??= matchingDoc.id;
        resolvedSpecialty ??= matchingDoc.specialty;
      }
    } catch (_) {}
  }

  // Resolve Hospital entity ID if not explicitly passed
  String? resolvedHospitalId = hospitalId ?? read(selectedHospitalIdProvider);
  if ((resolvedHospitalId == null || resolvedHospitalId.isEmpty) &&
      hospitalName != null &&
      hospitalName.isNotEmpty) {
    try {
      final hospRepo = read(hospitalRepositoryProvider);
      final hosps = await hospRepo.getHospitalModels(activeProfile.profileId);
      final matchingHosp = hosps
          .where(
            (h) =>
                h.name.trim().toLowerCase() ==
                hospitalName.trim().toLowerCase(),
          )
          .firstOrNull;
      if (matchingHosp != null) {
        resolvedHospitalId ??= matchingHosp.id;
      }
    } catch (_) {}
  }

  final String resolvedCurrency =
      currency ?? read(selectedCurrencyProvider) ?? read(appCurrencyProvider);

  final resolvedAppointmentId =
      appointmentId ?? read(selectedAppointmentIdProvider);

  final model = ConsultationModel(
    id: id,
    profileId: activeProfile.profileId,
    appointmentId: resolvedAppointmentId,
    doctorId: resolvedDoctorId,
    doctorName: cleanDocName.isNotEmpty ? cleanDocName : doctorName,
    doctorSpecialty: resolvedSpecialty,
    hospitalId: resolvedHospitalId,
    hospitalName: hospitalName,
    departmentId: departmentId ?? read(selectedDepartmentIdProvider),
    department: department,
    visitDate: visitDateTime,
    visitTime: formattedTime,
    chiefComplaint: chiefComplaint,
    diagnosis: diagnosis,
    clinicalNotes: clinicalNotes,
    isFollowUpRequired: isFollowUpRequired,
    followUpDate: followUpDate,
    followUpTime: formattedFollowUpTime,
    followUpReminder: followUpReminder,
    followUpNotes: followUpNotes,
    tags: tags,
    consultationFee: consultationFee,
    currency: resolvedCurrency,
    attachments: attachments,
    clientUuid: clientUuid,
    createdAt: DateTime.now(),
  );

  await read(consultationsListNotifierProvider.notifier)
      .saveConsultation(model);
}
