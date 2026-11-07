import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

class ProfileAllergiesSection extends StatelessWidget {
  final TextEditingController allergyInputController;
  final List<String> allergies;
  final bool allergiesConfirmedNone;
  final VoidCallback onAddAllergy;
  final ValueChanged<String> onRemoveAllergy;
  final ValueChanged<bool?> onAllergiesConfirmedNoneChanged;

  const ProfileAllergiesSection({
    super.key,
    required this.allergyInputController,
    required this.allergies,
    required this.allergiesConfirmedNone,
    required this.onAddAllergy,
    required this.onRemoveAllergy,
    required this.onAllergiesConfirmedNoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = allergies.isEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALLERGIES',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: allergyInputController,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Penicillin',
                    hintStyle: AppTypography.subtitle.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => onAddAllergy(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onAddAllergy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdBorder,
                  ),
                ),
                child: Text(
                  'ADD',
                  style: AppTypography.button.copyWith(
                    fontSize: 13,
                    letterSpacing: 0.5,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (allergies.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allergies.map((allergy) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      allergy,
                      style: AppTypography.bodyMedium.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onRemoveAllergy(allergy),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Text(
            'None added yet.',
            style: AppTypography.subtitle.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 14),
        Opacity(
          opacity: enabled ? 1.0 : 0.6,
          child: InkWell(
            onTap: enabled
                ? () => onAllergiesConfirmedNoneChanged(!allergiesConfirmedNone)
                : null,
            borderRadius: AppRadius.mdBorder,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: AppRadius.mdBorder,
                border: Border.all(color: colorScheme.outline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'No known allergies',
                      style: AppTypography.bodyMedium.copyWith(
                        color: enabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: allergiesConfirmedNone,
                      activeColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(
                        color: enabled
                            ? colorScheme.outline
                            : colorScheme.outline.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      onChanged: enabled
                          ? onAllergiesConfirmedNoneChanged
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
