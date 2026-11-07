import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../../../doctors/data/models/doctor_model.dart';
import '../../../../hospitals/data/models/hospital_model.dart';
import '../../providers/consultation_form_providers.dart';
import '../consultation_section_header.dart';
import '../consultation_selection_tile.dart';
import '../doctor_picker_sheet.dart';
import '../hospital_picker_sheet.dart';
import '../medical_department_picker_sheet.dart';

class ConsultationDoctorHospitalSection extends StatelessWidget {
  final String profileId;

  const ConsultationDoctorHospitalSection({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ConsultationSectionHeader(label: 'Doctor & Hospital'),
        _DoctorSelectionTile(profileId: profileId),
        const SizedBox(height: 10),
        _HospitalSelectionTile(profileId: profileId),
        const SizedBox(height: 10),
        _DepartmentSelectionTile(profileId: profileId),
      ],
    );
  }
}

class _DoctorSelectionTile extends ConsumerWidget {
  final String profileId;

  const _DoctorSelectionTile({required this.profileId});

  void _openDoctorPicker(
    BuildContext context,
    WidgetRef ref,
    String? currentDoctorId,
    String? currentDoctorName,
  ) {
    DoctorPickerSheet.show(
      context: context,
      currentDoctorId: currentDoctorId,
      currentDoctorName: currentDoctorName,
      onSelected: (DoctorModel doc) {
        ref.read(selectedDoctorProvider.notifier).state = doc.name;
        ref.read(selectedDoctorIdProvider.notifier).state = IdUtils.unprefix(
          doc.id,
        );
        ref.read(selectedDoctorSpecialtyProvider.notifier).state =
            doc.specialty;
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDoctor = ref.watch(selectedDoctorProvider);
    final selectedDoctorId = ref.watch(selectedDoctorIdProvider);
    final selectedDoctorSpecialty = ref.watch(selectedDoctorSpecialtyProvider);

    final doctorDisplayValue =
        selectedDoctor != null && selectedDoctor.isNotEmpty
        ? (selectedDoctorSpecialty != null &&
                  selectedDoctorSpecialty.isNotEmpty &&
                  selectedDoctorSpecialty != 'General Practice'
              ? '$selectedDoctor ($selectedDoctorSpecialty)'
              : selectedDoctor)
        : null;

    return ConsultationSelectionTile(
      icon: AppIcons.stethoscope,
      label: 'Doctor *',
      value: doctorDisplayValue,
      placeholder: 'Select doctor',
      onTap: () =>
          _openDoctorPicker(context, ref, selectedDoctorId, selectedDoctor),
    );
  }
}

class _HospitalSelectionTile extends ConsumerWidget {
  final String profileId;

  const _HospitalSelectionTile({required this.profileId});

  void _openHospitalPicker(
    BuildContext context,
    WidgetRef ref,
    String? currentHospitalId,
    String? currentHospitalName,
  ) {
    HospitalPickerSheet.show(
      context: context,
      currentHospitalId: currentHospitalId,
      currentHospitalName: currentHospitalName,
      onSelected: (HospitalModel hosp) {
        ref.read(selectedHospitalProvider.notifier).state = hosp.name;
        ref.read(selectedHospitalIdProvider.notifier).state = IdUtils.unprefix(
          hosp.id,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedHospital = ref.watch(selectedHospitalProvider);
    final selectedHospitalId = ref.watch(selectedHospitalIdProvider);

    return ConsultationSelectionTile(
      icon: AppIcons.hospital,
      label: 'Hospital (Optional)',
      value: selectedHospital,
      placeholder: 'Select hospital',
      onTap: () => _openHospitalPicker(
        context,
        ref,
        selectedHospitalId,
        selectedHospital,
      ),
    );
  }
}

class _DepartmentSelectionTile extends ConsumerWidget {
  final String profileId;

  const _DepartmentSelectionTile({required this.profileId});

  void _openDepartmentPicker(
    BuildContext context,
    WidgetRef ref,
    String? currentValue,
  ) {
    final currentIdStr = ref.read(selectedDepartmentIdProvider);
    final currentId = currentIdStr != null ? int.tryParse(currentIdStr) : null;

    MedicalDepartmentPickerSheet.show(
      context: context,
      currentDepartmentId: currentId,
      currentDepartmentName: currentValue,
      onSelected: (dept) {
        ref.read(selectedDepartmentProvider.notifier).state = dept.name;
        ref.read(selectedDepartmentIdProvider.notifier).state = dept.id
            .toString();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDepartment = ref.watch(selectedDepartmentProvider);

    return ConsultationSelectionTile(
      icon: AppIcons.calendar,
      label: 'Department (Optional)',
      value: selectedDepartment,
      placeholder: 'Select department',
      onTap: () => _openDepartmentPicker(context, ref, selectedDepartment),
    );
  }
}
