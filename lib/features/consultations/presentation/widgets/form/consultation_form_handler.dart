import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../../../profile/presentation/providers/profile_providers.dart';
import '../../../data/models/consultation_model.dart';
import '../../providers/consultation_providers.dart';

class ConsultationFormHandler {
  static Future<ConsultationModel?> populateInitialData({
    required WidgetRef ref,
    required String? consultationIdToEdit,
    required ConsultationModel? initialConsultation,
    required TextEditingController chiefComplaintController,
    required TextEditingController diagnosisController,
    required TextEditingController clinicalNotesController,
    required TextEditingController tagsController,
    required TextEditingController feeController,
    required TextEditingController followUpNotesController,
    bool Function()? isMounted,
  }) async {
    ConsultationModel? item = initialConsultation;
    final editId = consultationIdToEdit;
    final activeProfile = ref.read(activeProfileProvider);

    if (item == null && editId != null && activeProfile != null) {
      final repo = ref.read(consultationRepositoryProvider);
      item = await repo.getConsultationById(activeProfile.profileId, editId);
      if (isMounted != null && !isMounted()) return null;
    }

    if (item != null) {
      chiefComplaintController.text = item.chiefComplaint;
      diagnosisController.text = item.diagnosis;
      clinicalNotesController.text = item.clinicalNotes ?? '';
      tagsController.text = item.tags.join(', ');
      feeController.text =
          item.consultationFee != null && item.consultationFee! > 0
          ? (item.consultationFee! % 1 == 0
                ? item.consultationFee!.toInt().toString()
                : item.consultationFee!.toString())
          : '';
      followUpNotesController.text = item.followUpNotes ?? '';

      ref.read(selectedDoctorProvider.notifier).state = item.doctorName;
      ref.read(selectedDoctorIdProvider.notifier).state = item.doctorId != null
          ? IdUtils.unprefix(item.doctorId!)
          : null;
      ref.read(selectedDoctorSpecialtyProvider.notifier).state =
          item.doctorSpecialty;
      ref.read(selectedHospitalProvider.notifier).state = item.hospitalName;
      ref.read(selectedHospitalIdProvider.notifier).state =
          item.hospitalId != null ? IdUtils.unprefix(item.hospitalId!) : null;
      ref.read(selectedDepartmentProvider.notifier).state = item.department;
      ref
          .read(selectedDepartmentIdProvider.notifier)
          .state = item.departmentId != null
          ? IdUtils.unprefix(item.departmentId!)
          : null;
      ref.read(selectedAppointmentIdProvider.notifier).state =
          item.appointmentId;
      ref.read(visitDateProvider.notifier).state = item.visitDate;
      if (item.visitTime != null && item.visitTime!.isNotEmpty) {
        final parts = item.visitTime!.split(':');
        if (parts.length >= 2) {
          int h = int.tryParse(parts[0].trim()) ?? 10;
          final minPart = parts[1].trim();
          int m = 0;
          if (minPart.toLowerCase().contains('pm') && h < 12) {
            h += 12;
          } else if (minPart.toLowerCase().contains('am') && h == 12) {
            h = 0;
          }
          final mMatch = RegExp(r'\d+').firstMatch(minPart);
          if (mMatch != null) {
            m = int.tryParse(mMatch.group(0)!) ?? 0;
          }
          ref.read(visitTimeProvider.notifier).state = TimeOfDay(
            hour: h.clamp(0, 23),
            minute: m.clamp(0, 59),
          );
        }
      }
      ref.read(isFollowUpEnabledProvider.notifier).state =
          item.isFollowUpRequired;
      ref.read(followUpDateProvider.notifier).state = item.followUpDate;
      ref.read(selectedCurrencyProvider.notifier).state = item.currency;
      ref.read(consultationAttachmentsProvider.notifier).state =
          item.attachments;
      return item;
    } else {
      resetConsultationForm(ref);
      return null;
    }
  }

  static Future<void> submit({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required TextEditingController chiefComplaintController,
    required TextEditingController diagnosisController,
    required TextEditingController clinicalNotesController,
    required TextEditingController tagsController,
    required TextEditingController feeController,
    required TextEditingController followUpNotesController,
    required String? consultationIdToEdit,
    required ConsultationModel? initialConsultation,
    required void Function(bool isSaving) onSavingChanged,
  }) async {
    final selectedDoctor = ref.read(selectedDoctorProvider);
    if (selectedDoctor == null || selectedDoctor.isEmpty) {
      if (!context.mounted) return;
      context.showErrorSnackBar('Please select a doctor for this consultation');
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final visitDate = ref.read(visitDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visitDateOnly = DateTime(
      visitDate.year,
      visitDate.month,
      visitDate.day,
    );
    if (visitDateOnly.isAfter(today)) {
      if (!context.mounted) return;
      context.showErrorSnackBar(
        'Consultation visit date cannot be in the future',
      );
      return;
    }

    onSavingChanged(true);

    try {
      final tagsList = tagsController.text.trim().isNotEmpty
          ? tagsController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];

      final feeAmount = double.tryParse(feeController.text.trim());

      final isEditing =
          (consultationIdToEdit != null &&
              consultationIdToEdit.trim().isNotEmpty) ||
          (initialConsultation != null &&
              initialConsultation.id.trim().isNotEmpty);
      final editId = isEditing
          ? (consultationIdToEdit ??
                (initialConsultation?.id.trim().isNotEmpty == true
                    ? initialConsultation?.id
                    : null))
          : null;
      final clientUuid = isEditing ? initialConsultation?.clientUuid : null;

      await saveConsultationRecord(
        ref: ref,
        doctorName: selectedDoctor,
        doctorId: ref.read(selectedDoctorIdProvider),
        doctorSpecialty: ref.read(selectedDoctorSpecialtyProvider),
        hospitalName: ref.read(selectedHospitalProvider),
        hospitalId: ref.read(selectedHospitalIdProvider),
        departmentId: ref.read(selectedDepartmentIdProvider),
        department: ref.read(selectedDepartmentProvider),
        appointmentId: ref.read(selectedAppointmentIdProvider),
        visitDate: ref.read(visitDateProvider),
        visitTime: ref.read(visitTimeProvider),
        chiefComplaint: chiefComplaintController.text.trim(),
        diagnosis: diagnosisController.text.trim(),
        clinicalNotes: clinicalNotesController.text.trim().isNotEmpty
            ? clinicalNotesController.text.trim()
            : null,
        isFollowUpRequired: ref.read(isFollowUpEnabledProvider),
        followUpDate: ref.read(followUpDateProvider),
        followUpTime: ref.read(followUpTimeProvider),
        followUpReminder: ref.read(followUpReminderProvider),
        followUpNotes: followUpNotesController.text.trim().isNotEmpty
            ? followUpNotesController.text.trim()
            : null,
        tags: tagsList,
        consultationFee: feeAmount,
        currency: ref.read(selectedCurrencyProvider),
        attachments: ref.read(consultationAttachmentsProvider),
        consultationIdToEdit: editId,
        clientUuid: clientUuid,
      );

      if (!context.mounted) return;

      context.showSuccessSnackBar(
        isEditing
            ? 'Consultation record updated successfully'
            : 'Consultation record saved successfully',
      );

      resetConsultationForm(ref);
      Navigator.of(context).pop();
    } on AppException catch (appErr) {
      if (!context.mounted) return;
      context.showErrorSnackBar(appErr.message);
    } catch (err) {
      if (!context.mounted) return;
      context.showErrorSnackBar(
        'Failed to save consultation: ${err.toString()}',
      );
    } finally {
      if (context.mounted) {
        onSavingChanged(false);
      }
    }
  }
}
