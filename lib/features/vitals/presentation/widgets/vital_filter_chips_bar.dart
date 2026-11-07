import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';

class VitalFilterChipsBar extends StatelessWidget {
  final String selectedFilterType;
  final ValueChanged<String> onFilterSelected;

  const VitalFilterChipsBar({
    super.key,
    required this.selectedFilterType,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = const [
      {'id': 'All', 'label': 'All'},
      {'id': 'blood_pressure', 'label': 'Blood Pressure'},
      {'id': 'blood_glucose', 'label': 'Blood Glucose'},
      {'id': 'heart_rate', 'label': 'Heart Rate'},
      {'id': 'spo2', 'label': 'SpO₂'},
      {'id': 'temperature', 'label': 'Temperature'},
      {'id': 'bmi', 'label': 'BMI'},
      {'id': 'respiratory_rate', 'label': 'Respiratory Rate'},
    ];

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = selectedFilterType == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeInOut,
                style: AppTypography.caption.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                child: Text(cat['label']!),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onFilterSelected(cat['id']!);
                }
              },
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }
}
