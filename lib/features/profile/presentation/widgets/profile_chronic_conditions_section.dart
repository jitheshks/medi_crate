import 'package:flutter/material.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

class ProfileChronicConditionsSection extends StatelessWidget {
  final TextEditingController conditionInputController;
  final List<String> chronicConditions;
  final bool chronicConditionsConfirmedNone;
  final VoidCallback onAddCondition;
  final ValueChanged<String> onRemoveCondition;
  final ValueChanged<bool?> onChronicConditionsConfirmedNoneChanged;

  const ProfileChronicConditionsSection({
    super.key,
    required this.conditionInputController,
    required this.chronicConditions,
    required this.chronicConditionsConfirmedNone,
    required this.onAddCondition,
    required this.onRemoveCondition,
    required this.onChronicConditionsConfirmedNoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !chronicConditionsConfirmedNone;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHRONIC CONDITIONS',
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
                  controller: conditionInputController,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Hypertension',
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
                  onSubmitted: (_) => onAddCondition(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onAddCondition,
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
        if (chronicConditions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chronicConditions.map((condition) {
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
                      condition,
                      style: AppTypography.bodyMedium.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onRemoveCondition(condition),
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
                ? () => onChronicConditionsConfirmedNoneChanged(
                    !chronicConditionsConfirmedNone,
                  )
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
                      'No chronic conditions',
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
                      value: chronicConditionsConfirmedNone,
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
                          ? onChronicConditionsConfirmedNoneChanged
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
