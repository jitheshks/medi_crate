import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../data/models/appointment_model.dart';
import '../../providers/appointment_providers.dart';
import 'appointment_form_controller.dart';

class AppointmentFormSaveHelper {
  static Future<AppointmentModel?> loadInitialData({
    required WidgetRef ref,
    required String profileId,
    required String? appointmentIdToEdit,
    required AppointmentFormController formCtrl,
  }) async {
    AppointmentModel? original;

    if (appointmentIdToEdit != null && appointmentIdToEdit.isNotEmpty) {
      final repository = ref.read(appointmentRepositoryProvider);
      original = await repository.getAppointmentById(
        profileId,
        appointmentIdToEdit,
      );

      if (original != null) {
        formCtrl.populateFromAppointment(original);
      }
    }

    try {
      final appRepo = ref.read(appointmentRepositoryProvider);
      final consultRepo = ref.read(consultationRepositoryProvider);

      final rawApps = await appRepo.getAppointments(profileId);
      final rawConsults = await consultRepo.getConsultations(profileId);

      final suggestions = <String>{};
      for (final a in rawApps) {
        final t = a['title']?.toString();
        if (t != null && t.trim().isNotEmpty) suggestions.add(t.trim());
      }
      for (final c in rawConsults) {
        final r = c['reason']?.toString();
        if (r != null && r.trim().isNotEmpty) suggestions.add(r.trim());
      }

      if (suggestions.isEmpty) {
        suggestions.addAll([
          'Cardiology Follow-up',
          'Thyroid Level Checkup',
          'Annual Physical Routine',
          'Dental Cleaning & Review',
        ]);
      }

      formCtrl.titleSuggestions = suggestions.take(5).toList();
    } catch (_) {}

    return original;
  }

  static AppointmentModel buildAppointmentModel({
    required AppointmentFormController formCtrl,
    required String profileId,
    required AppointmentModel? originalAppointment,
    String? defaultCurrency,
  }) {
    final combinedDateTime = DateTime(
      formCtrl.selectedDate.year,
      formCtrl.selectedDate.month,
      formCtrl.selectedDate.day,
      formCtrl.selectedTime.hour,
      formCtrl.selectedTime.minute,
    );

    double? parsedCost;
    if (formCtrl.costController.text.trim().isNotEmpty) {
      parsedCost = double.tryParse(formCtrl.costController.text.trim());
    }

    final appointmentId =
        originalAppointment?.id ??
        'appointment_${DateTime.now().microsecondsSinceEpoch}';

    final resolvedCurrency =
        originalAppointment?.currency ??
        formCtrl.selectedCurrency ??
        defaultCurrency ??
        'INR';

    return AppointmentModel(
      id: appointmentId,
      profileId: profileId,
      title: formCtrl.titleController.text.trim(),
      doctorName: formCtrl.selectedDoctorName!,
      doctorId: formCtrl.selectedDoctorId,
      doctorSpecialty: formCtrl.selectedDoctorSpecialty,
      hospitalName: formCtrl.selectedHospitalName,
      hospitalId: formCtrl.selectedHospitalId,
      departmentId: formCtrl.selectedDepartmentId,
      department: formCtrl.selectedDepartment,
      date: combinedDateTime,
      reminderEnabled: formCtrl.reminderEnabled,
      notes: formCtrl.notesController.text.trim().isNotEmpty
          ? formCtrl.notesController.text.trim()
          : null,
      cost: parsedCost,
      currency: resolvedCurrency,
      status: originalAppointment?.status ?? 'upcoming',
      clientUuid: originalAppointment?.clientUuid,
      createdAt: originalAppointment?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Future<DateTime?> pickDate(
    BuildContext context,
    DateTime initialDate, {
    bool isEditing = false,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = isEditing ? DateTime(1900) : today;
    final resolvedInitial = initialDate.isBefore(firstDate)
        ? firstDate
        : initialDate;
    return showDatePicker(
      context: context,
      initialDate: resolvedInitial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
  }

  static Future<TimeOfDay?> pickTime(
    BuildContext context,
    TimeOfDay initialTime,
  ) {
    return showTimePicker(context: context, initialTime: initialTime);
  }
}
