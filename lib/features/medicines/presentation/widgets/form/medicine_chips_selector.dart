import 'package:flutter/material.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';

const List<String> medicineForms = [
  'Tablet',
  'Capsule',
  'Syrup',
  'Inhaler',
  'Injection',
  'Cream',
  'Drops',
  'Other',
];

const List<String> medicineFrequencies = [
  'Once daily',
  'Twice daily',
  'Three times daily',
  'As needed',
  'Other',
];

class MedicineChipsSelector extends StatelessWidget {
  final String? selectedForm;
  final ValueChanged<String?> onFormSelected;
  final String? selectedFrequency;
  final ValueChanged<String?> onFrequencySelected;

  const MedicineChipsSelector({
    super.key,
    required this.selectedForm,
    required this.onFormSelected,
    required this.selectedFrequency,
    required this.onFrequencySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FORM
        Text(
          'FORM',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: medicineForms.map((formOption) {
            final isSelected = selectedForm == formOption;
            return ChoiceChip(
              label: AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeInOut,
                style: AppTypography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
                child: Text(formOption),
              ),
              selected: isSelected,
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              side: BorderSide(
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
              onSelected: (selected) {
                onFormSelected(selected ? formOption : null);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),

        // FREQUENCY
        Text(
          'FREQUENCY',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: medicineFrequencies.map((freqOption) {
            final isSelected = selectedFrequency == freqOption;
            return ChoiceChip(
              label: AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeInOut,
                style: AppTypography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
                child: Text(freqOption),
              ),
              selected: isSelected,
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              side: BorderSide(
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
              onSelected: (selected) {
                onFrequencySelected(selected ? freqOption : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
