import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_typography.dart';

/// GenderChipSelector renders the optional gender selection chips.
class GenderChipSelector extends StatelessWidget {
  final String? selectedGender;
  final ValueChanged<String?> onSelected;

  const GenderChipSelector({
    super.key,
    this.selectedGender,
    required this.onSelected,
  });

  static const List<String> _options = ['Male', 'Female', 'Others'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GENDER (OPTIONAL)',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _options.map((option) {
            final isSelected =
                selectedGender?.toLowerCase() == option.toLowerCase();
            return ChoiceChip(
              label: AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeInOut,
                style: AppTypography.caption.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(option),
              ),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: colorScheme.primaryContainer,
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                ),
              ),
              onSelected: (selected) => onSelected(selected ? option : null),
            );
          }).toList(),
        ),
      ],
    );
  }
}
