import 'package:flutter/material.dart';
import '../../../data/models/doctor_model.dart';

/// Form controller encapsulating draft inputs, validation key, and lifecycle
/// for Add/Edit Doctor workflows.
class DoctorFormController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController specialtyController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  List<String> selectedHospitalIds = [];

  void populateFromDoctor(DoctorModel doctor) {
    nameController.text = doctor.name;
    specialtyController.text = doctor.specialty;
    selectedHospitalIds = List.from(doctor.hospitalIds);
    phoneController.text = doctor.phone ?? '';
    emailController.text = doctor.email ?? '';
    notesController.text = doctor.notes ?? '';
  }

  DoctorModel buildDoctorModel({
    required String profileId,
    DoctorModel? originalDoctor,
    String? doctorIdToEdit,
  }) {
    final doctorId =
        originalDoctor?.id ??
        doctorIdToEdit ??
        'doctor_${DateTime.now().microsecondsSinceEpoch}';

    return DoctorModel(
      id: doctorId,
      profileId: profileId,
      name: nameController.text.trim(),
      specialty: specialtyController.text.trim(),
      hospitalIds: selectedHospitalIds,
      hospitalName: originalDoctor?.hospitalName,
      phone: phoneController.text.trim().isNotEmpty
          ? phoneController.text.trim()
          : null,
      email: emailController.text.trim().isNotEmpty
          ? emailController.text.trim()
          : null,
      notes: notesController.text.trim().isNotEmpty
          ? notesController.text.trim()
          : null,
      isFavorite: originalDoctor?.isFavorite ?? false,
      clientUuid: originalDoctor?.clientUuid,
      createdAt: originalDoctor?.createdAt ?? DateTime.now(),
    );
  }

  void dispose() {
    nameController.dispose();
    specialtyController.dispose();
    phoneController.dispose();
    emailController.dispose();
    notesController.dispose();
  }
}
