import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

/// DobPickerField renders the Date of Birth input trigger with calendar icon.
class DobPickerField extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;

  const DobPickerField({
    super.key,
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE OF BIRTH',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdBorder,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(color: colorScheme.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('dd / MM / yyyy').format(selectedDate!)
                        : 'dd / mm / yyyy',
                    style: AppTypography.bodyMedium.copyWith(
                      color: selectedDate != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  AppIcons.calendar,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
