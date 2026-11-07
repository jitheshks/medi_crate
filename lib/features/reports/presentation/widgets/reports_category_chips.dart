import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

class ReportsCategoryChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  static const List<String> categories = [
    'ALL',
    'Lab Test',
    'Imaging',
    'Prescription',
    'Discharge',
    'Certificate',
    'Vaccination',
    'Referral',
    'Other',
  ];

  const ReportsCategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected =
              selectedCategory.toUpperCase() == cat.toUpperCase();

          return FilterChip(
            selected: isSelected,
            label: AnimatedDefaultTextStyle(
              duration: duration,
              curve: Curves.easeInOut,
              style: AppTypography.caption.copyWith(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(cat),
            ),
            selectedColor: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            side: BorderSide(
              color: isSelected ? colorScheme.primary : colorScheme.outline,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            showCheckmark: false,
            onSelected: (_) => onCategorySelected(cat),
          );
        },
      ),
    );
  }
}
