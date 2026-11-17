import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_typography.dart';

class ReportCategoryChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  static const List<String> categories = [
    'LAB TEST',
    'IMAGING',
    'PRESCRIPTION',
    'DISCHARGE',
    'CERTIFICATE',
    'VACCINATION',
    'REFERRAL',
    'OTHER',
  ];

  const ReportCategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = selectedCategory.toUpperCase() == cat;
        return ChoiceChip(
          label: AnimatedDefaultTextStyle(
            duration: duration,
            curve: Curves.easeInOut,
            style: AppTypography.caption.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
            child: Text(cat),
          ),
          selected: isSelected,
          selectedColor: colorScheme.primary,
          backgroundColor: colorScheme.surface,
          onSelected: (_) {
            onCategoryChanged(cat);
          },
        );
      }).toList(),
    );
  }
}
