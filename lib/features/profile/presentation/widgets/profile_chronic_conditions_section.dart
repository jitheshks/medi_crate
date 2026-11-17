import 'package:material_ui/material_ui.dart';

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
    final isInputEnabled = !chronicConditionsConfirmedNone;
    final isCheckboxEnabled = chronicConditions.isEmpty;
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
                  enabled: isInputEnabled,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isInputEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Hypertension',
                    hintStyle: AppTypography.subtitle.copyWith(
                      color: isInputEnabled
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: isInputEnabled
                        ? colorScheme.surface
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                    disabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdBorder,
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: isInputEnabled ? (_) => onAddCondition() : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isInputEnabled ? onAddCondition : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  disabledBackgroundColor:
                      colorScheme.onSurface.withValues(alpha: 0.12),
                  disabledForegroundColor:
                      colorScheme.onSurface.withValues(alpha: 0.38),
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
                    color: isInputEnabled
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface.withValues(alpha: 0.38),
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
          opacity: isCheckboxEnabled ? 1.0 : 0.6,
          child: InkWell(
            onTap: isCheckboxEnabled
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
                        color: isCheckboxEnabled
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
                        color: isCheckboxEnabled
                            ? colorScheme.outline
                            : colorScheme.outline.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      onChanged: isCheckboxEnabled
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
