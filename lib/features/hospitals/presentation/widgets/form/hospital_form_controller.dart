import 'package:flutter/material.dart';

import '../../../data/models/hospital_model.dart';

/// Form controller encapsulating draft inputs, validation key, and lifecycle
/// for Add/Edit Hospital workflows.
class HospitalFormController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController typeController = TextEditingController(
    text: 'Hospital',
  );
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  void populateFromHospital(HospitalModel hospital) {
    nameController.text = hospital.name;
    typeController.text = hospital.type ?? 'Hospital';
    addressController.text = hospital.address ?? '';
    phoneController.text = hospital.phone ?? '';
    emailController.text = hospital.email ?? '';
    notesController.text = hospital.notes ?? '';
  }

  HospitalModel buildHospitalModel({
    required String profileId,
    HospitalModel? originalHospital,
    String? hospitalIdToEdit,
  }) {
    final hospitalId =
        originalHospital?.id ??
        (hospitalIdToEdit != null && hospitalIdToEdit.trim().isNotEmpty
            ? hospitalIdToEdit.trim()
            : null) ??
        'hospital_${DateTime.now().microsecondsSinceEpoch}';

    return HospitalModel(
      id: hospitalId,
      profileId: profileId,
      name: nameController.text.trim(),
      type: typeController.text.trim().isNotEmpty
          ? typeController.text.trim()
          : 'Hospital',
      address: addressController.text.trim().isNotEmpty
          ? addressController.text.trim()
          : null,
      phone: phoneController.text.trim().isNotEmpty
          ? phoneController.text.trim()
          : null,
      email: emailController.text.trim().isNotEmpty
          ? emailController.text.trim()
          : null,
      notes: notesController.text.trim().isNotEmpty
          ? notesController.text.trim()
          : null,
      clientUuid: originalHospital?.clientUuid,
      createdAt: originalHospital?.createdAt ?? DateTime.now(),
    );
  }

  void dispose() {
    nameController.dispose();
    typeController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    notesController.dispose();
  }
}
