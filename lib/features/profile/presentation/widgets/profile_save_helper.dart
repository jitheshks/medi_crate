import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../data/models/profile_model.dart';
import '../providers/profile_providers.dart';

class ProfileSaveHelper {
  static Future<void> saveProfile({
    required BuildContext context,
    required WidgetRef ref,
    required ProfileModel activeProfile,
    required String nameText,
    required String heightText,
    required String weightText,
    required DateTime? selectedDob,
    required String? selectedGender,
    required String? selectedBloodGroup,
    required String? photoPath,
    required List<String> allergies,
    required bool allergiesConfirmedNone,
    required List<String> chronicConditions,
    required bool chronicConditionsConfirmedNone,
  }) async {
    try {
      double? parsedHeight;
      if (heightText.trim().isNotEmpty) {
        parsedHeight = double.tryParse(heightText.trim());
        if (parsedHeight == null || parsedHeight <= 0) {
          context.showSnackBar('Please enter a valid positive height');
          return;
        }
      }

      double? parsedWeight;
      if (weightText.trim().isNotEmpty) {
        parsedWeight = double.tryParse(weightText.trim());
        if (parsedWeight == null || parsedWeight <= 0) {
          context.showSnackBar('Please enter a valid positive weight');
          return;
        }
      }

      String? dobStr;
      if (selectedDob != null) {
        dobStr =
            "${selectedDob.year.toString().padLeft(4, '0')}-${selectedDob.month.toString().padLeft(2, '0')}-${selectedDob.day.toString().padLeft(2, '0')}";
      }

      final updatedProfile = activeProfile.copyWith(
        fullName: nameText.trim(),
        dateOfBirth: dobStr,
        clearDateOfBirth: dobStr == null,
        gender: selectedGender,
        clearGender: selectedGender == null,
        bloodGroup: selectedBloodGroup,
        clearBloodGroup: selectedBloodGroup == null,
        height: parsedHeight,
        clearHeight: parsedHeight == null,
        weight: parsedWeight,
        clearWeight: parsedWeight == null,
        photo: photoPath,
        clearPhoto: photoPath == null,
        allergies: allergies,
        allergiesConfirmedNone: allergiesConfirmedNone,
        chronicConditions: chronicConditions,
        chronicConditionsConfirmedNone: chronicConditionsConfirmedNone,
      );

      await ref
          .read(profilesListProvider.notifier)
          .updateProfile(updatedProfile);

      ref.read(activeProfileProvider.notifier).selectProfile(updatedProfile);

      if (context.mounted) {
        context.showSnackBar(
          'Profile saved successfully',
          duration: const Duration(seconds: 2),
        );
        context.popOrGo(AppRoutes.profiles);
      }
    } catch (e) {
      if (context.mounted) {
        final message = e is AppException
            ? e.userFriendlyMessage
            : "Couldn't save profile details. Please try again.";
        context.showSnackBar(message);
      }
    }
  }
}
