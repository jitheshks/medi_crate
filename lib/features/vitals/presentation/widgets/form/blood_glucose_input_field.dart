import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../shared/widgets/forms/custom_text_field.dart';

class BloodGlucoseInputField extends StatelessWidget {
  final TextEditingController valueController;
  final String glucoseContext;
  final ValueChanged<String> onGlucoseContextChanged;

  const BloodGlucoseInputField({
    super.key,
    required this.valueController,
    required this.glucoseContext,
    required this.onGlucoseContextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFasting = glucoseContext == 'fasting';
    final isRandom = glucoseContext == 'random';
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Blood glucose value in mg/dL',
          child: CustomTextField(
            controller: valueController,
            label: 'VALUE (MG/DL)',
            hint: 'e.g. 100',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a blood glucose value.';
              }
              final num = double.tryParse(val.trim());
              if (num == null) {
                return 'Please enter a valid number.';
              }
              if (num < 1 || num > 600) {
                return 'Blood glucose must be between 1 and 600 mg/dL.';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'MEASUREMENT TYPE',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeInOut,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isFasting
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    child: const Text('Fasting'),
                  ),
                ),
                selected: isFasting,
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isFasting
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    onGlucoseContextChanged('fasting');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeInOut,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isRandom
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    child: const Text('Random'),
                  ),
                ),
                selected: isRandom,
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isRandom
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    onGlucoseContextChanged('random');
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
