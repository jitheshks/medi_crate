import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../consultations/data/models/consultation_model.dart';
import '../../../../consultations/presentation/widgets/consultation_picker_sheet.dart';
import '../../../../consultations/presentation/widgets/doctor_picker_sheet.dart';
import '../../../../consultations/presentation/widgets/hospital_picker_sheet.dart';
import '../../../../doctors/data/models/doctor_model.dart';
import '../../../../hospitals/data/models/hospital_model.dart';

class ReportEntityPickerHelper {
  static void openConsultationPicker({
    required BuildContext context,
    required List<ConsultationModel> consultations,
    required List<DoctorModel> doctors,
    required List<HospitalModel> hospitals,
    required String? consultationId,
    required Function({
      required String id,
      required String title,
      required String? doctorId,
      required String? doctorName,
      required String? hospitalId,
      required String? hospitalName,
    })
    onSelected,
  }) {
    final options = consultations
        .map(
          (c) =>
              '${c.diagnosis} (${DateFormat('d MMM yyyy').format(c.visitDate)})',
        )
        .toList();

    String? currentVal;
    if (consultationId != null) {
      try {
        final match = consultations.firstWhere((c) => c.id == consultationId);
        currentVal =
            '${match.diagnosis} (${DateFormat('d MMM yyyy').format(match.visitDate)})';
      } catch (_) {}
    }

    ConsultationPickerSheet.show(
      context: context,
      title: 'Select Consultation',
      placeholderHint: 'Search consultations...',
      options: options,
      currentValue: currentVal,
      onSelected: (selectedLabel) {
        final match = consultations.firstWhere(
          (c) =>
              '${c.diagnosis} (${DateFormat('d MMM yyyy').format(c.visitDate)})' ==
              selectedLabel,
          orElse: () => consultations.first,
        );

        DoctorModel? resolvedDoc;
        if (match.doctorId != null) {
          try {
            resolvedDoc = doctors.firstWhere((d) => d.id == match.doctorId);
          } catch (_) {}
        }

        HospitalModel? resolvedHosp;
        if (match.hospitalId != null) {
          try {
            resolvedHosp = hospitals.firstWhere(
              (h) => h.id == match.hospitalId,
            );
          } catch (_) {}
        }

        onSelected(
          id: match.id,
          title: match.diagnosis,
          doctorId: resolvedDoc?.id ?? match.doctorId,
          doctorName: resolvedDoc?.name ?? match.doctorName,
          hospitalId: resolvedHosp?.id ?? match.hospitalId,
          hospitalName: resolvedHosp?.name ?? match.hospitalName,
        );
      },
    );
  }

  /// Opens the shared reactive [DoctorPickerSheet], which `ref.watch`es
  /// `doctorsListProvider` internally. The profile-scoped doctor list is
  /// therefore always live and self-heals if the provider was momentarily
  /// empty (e.g. transient null active profile) — never a frozen snapshot.
  static void openDoctorPicker({
    required BuildContext context,
    String? currentDoctorId,
    String? currentDoctorName,
    required void Function(DoctorModel doctor) onSelected,
  }) {
    DoctorPickerSheet.show(
      context: context,
      currentDoctorId: currentDoctorId,
      currentDoctorName: currentDoctorName,
      onSelected: onSelected,
    );
  }

  /// Opens the shared reactive [HospitalPickerSheet], which `ref.watch`es
  /// `hospitalsListProvider` internally (same rationale as [openDoctorPicker]).
  static void openHospitalPicker({
    required BuildContext context,
    String? currentHospitalId,
    String? currentHospitalName,
    required void Function(HospitalModel hospital) onSelected,
  }) {
    HospitalPickerSheet.show(
      context: context,
      currentHospitalId: currentHospitalId,
      currentHospitalName: currentHospitalName,
      onSelected: onSelected,
    );
  }
}
