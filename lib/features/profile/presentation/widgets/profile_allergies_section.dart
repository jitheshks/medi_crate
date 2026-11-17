import 'package:material_ui/material_ui.dart';

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
    final isInputEnabled = !allergiesConfirmedNone;
    final isCheckboxEnabled = allergies.isEmpty;
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
                  enabled: isInputEnabled,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isInputEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Penicillin',
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
                  onSubmitted: isInputEnabled ? (_) => onAddAllergy() : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isInputEnabled ? onAddAllergy : null,
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
          opacity: isCheckboxEnabled ? 1.0 : 0.6,
          child: InkWell(
            onTap: isCheckboxEnabled
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
                      value: allergiesConfirmedNone,
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
