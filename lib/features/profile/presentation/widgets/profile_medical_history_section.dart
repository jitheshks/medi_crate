import 'package:flutter/material.dart';
import 'profile_allergies_section.dart';
import 'profile_chronic_conditions_section.dart';

class ProfileMedicalHistorySection extends StatelessWidget {
  final TextEditingController allergyInputController;
  final List<String> allergies;
  final bool allergiesConfirmedNone;
  final VoidCallback onAddAllergy;
  final ValueChanged<String> onRemoveAllergy;
  final ValueChanged<bool?> onAllergiesConfirmedNoneChanged;

  final TextEditingController conditionInputController;
  final List<String> chronicConditions;
  final bool chronicConditionsConfirmedNone;
  final VoidCallback onAddCondition;
  final ValueChanged<String> onRemoveCondition;
  final ValueChanged<bool?> onChronicConditionsConfirmedNoneChanged;

  const ProfileMedicalHistorySection({
    super.key,
    required this.allergyInputController,
    required this.allergies,
    required this.allergiesConfirmedNone,
    required this.onAddAllergy,
    required this.onRemoveAllergy,
    required this.onAllergiesConfirmedNoneChanged,
    required this.conditionInputController,
    required this.chronicConditions,
    required this.chronicConditionsConfirmedNone,
    required this.onAddCondition,
    required this.onRemoveCondition,
    required this.onChronicConditionsConfirmedNoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileAllergiesSection(
          allergyInputController: allergyInputController,
          allergies: allergies,
          allergiesConfirmedNone: allergiesConfirmedNone,
          onAddAllergy: onAddAllergy,
          onRemoveAllergy: onRemoveAllergy,
          onAllergiesConfirmedNoneChanged: onAllergiesConfirmedNoneChanged,
        ),
        const SizedBox(height: 24),
        ProfileChronicConditionsSection(
          conditionInputController: conditionInputController,
          chronicConditions: chronicConditions,
          chronicConditionsConfirmedNone: chronicConditionsConfirmedNone,
          onAddCondition: onAddCondition,
          onRemoveCondition: onRemoveCondition,
          onChronicConditionsConfirmedNoneChanged:
              onChronicConditionsConfirmedNoneChanged,
        ),
      ],
    );
  }
}
