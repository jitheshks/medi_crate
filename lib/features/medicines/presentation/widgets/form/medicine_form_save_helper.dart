import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../profile/presentation/providers/profile_providers.dart';
import '../../../data/models/medicine_model.dart';
import '../../providers/medicine_providers.dart';
import 'medicine_form_controller.dart';

class MedicineFormSaveHelper {
  static Future<MedicineModel?> loadInitial({
    required WidgetRef ref,
    required String? medicineIdToEdit,
    required MedicineModel? initialMedicine,
    required MedicineFormController formCtrl,
  }) async {
    if (initialMedicine != null) {
      formCtrl.populateFromModel(initialMedicine);
      return initialMedicine;
    } else if (medicineIdToEdit != null) {
      final activeProfile = ref.read(activeProfileProvider);
      if (activeProfile != null) {
        final repo = ref.read(medicineRepositoryProvider);
        final model = await repo.getMedicineById(
          activeProfile.profileId,
          medicineIdToEdit,
        );
        if (model != null) {
          formCtrl.populateFromModel(model);
        }
        return model;
      }
    }
    return null;
  }

  static MedicineModel buildModel({
    required MedicineFormController formCtrl,
    required String profileId,
    required String? medicineIdToEdit,
    required MedicineModel? initialMedicine,
  }) {
    final isEdit = medicineIdToEdit != null;
    final existingId =
        initialMedicine?.id ??
        (isEdit
            ? medicineIdToEdit
            : 'medicine_${DateTime.now().microsecondsSinceEpoch}');

    final reminderTimeStrings = formCtrl.reminderTimes
        .map(
          (t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        )
        .toList();

    return MedicineModel(
      id: existingId,
      profileId: profileId,
      medicineName: formCtrl.nameController.text.trim(),
      dosage: formCtrl.dosageController.text.trim(),
      form: formCtrl.selectedForm,
      frequency: formCtrl.selectedFrequency,
      startDate: formCtrl.startDate,
      endDate: formCtrl.endDate,
      reminder: formCtrl.reminder,
      reminderTimes: reminderTimeStrings,
      linkedConsultationId: formCtrl.linkedConsultationId,
      linkedConsultationTitle: formCtrl.linkedConsultationTitle,
      notes: formCtrl.notesController.text.trim().isEmpty
          ? null
          : formCtrl.notesController.text.trim(),
      clientUuid: initialMedicine?.clientUuid,
      createdAt: initialMedicine?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
