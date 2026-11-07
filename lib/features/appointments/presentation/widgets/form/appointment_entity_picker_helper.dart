import 'package:flutter/material.dart';

import '../../../../consultations/data/models/medical_department_model.dart';
import '../../../../consultations/presentation/widgets/doctor_picker_sheet.dart';
import '../../../../consultations/presentation/widgets/hospital_picker_sheet.dart';
import '../../../../consultations/presentation/widgets/medical_department_picker_sheet.dart';
import '../../../../doctors/data/models/doctor_model.dart';
import '../../../../hospitals/data/models/hospital_model.dart';

class AppointmentEntityPickerHelper {
  static void openDoctorPicker({
    required BuildContext context,
    String? currentDoctorId,
    String? currentDoctorName,
    required ValueChanged<DoctorModel> onSelected,
  }) {
    DoctorPickerSheet.show(
      context: context,
      currentDoctorId: currentDoctorId,
      currentDoctorName: currentDoctorName,
      onSelected: onSelected,
    );
  }

  static void openHospitalPicker({
    required BuildContext context,
    String? currentHospitalId,
    String? currentHospitalName,
    required ValueChanged<HospitalModel> onSelected,
  }) {
    HospitalPickerSheet.show(
      context: context,
      currentHospitalId: currentHospitalId,
      currentHospitalName: currentHospitalName,
      onSelected: onSelected,
    );
  }

  static void openDepartmentPicker({
    required BuildContext context,
    required String? currentDepartment,
    int? currentDepartmentId,
    required ValueChanged<MedicalDepartmentModel> onSelected,
  }) {
    MedicalDepartmentPickerSheet.show(
      context: context,
      currentDepartmentId: currentDepartmentId,
      currentDepartmentName: currentDepartment,
      onSelected: onSelected,
    );
  }
}
