import 'package:flutter/material.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';

class AppointmentTitleField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionSelected;

  const AppointmentTitleField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TITLE *',
          style: AppTypography.labelSmall.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Cardiology Follow-up',
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter appointment title';
            }
            return null;
          },
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: suggestions.map((sug) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(sug),
                    labelStyle: AppTypography.caption.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      side: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    onPressed: () => onSuggestionSelected(sug),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
