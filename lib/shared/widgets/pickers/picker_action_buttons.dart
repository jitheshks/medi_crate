import 'package:flutter/material.dart';
import '../../../core/constants/app_radius.dart';

/// Presentation component providing standard Back and Save & Select action buttons
/// for entity creation flows within modal pickers.
class PickerActionButtons extends StatelessWidget {
  final bool isSaving;
  final VoidCallback? onBack;
  final VoidCallback? onSubmit;
  final String submitLabel;

  const PickerActionButtons({
    super.key,
    this.isSaving = false,
    required this.onBack,
    required this.onSubmit,
    this.submitLabel = 'Save & Select',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSaving ? null : onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isSaving ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(submitLabel),
          ),
        ),
      ],
    );
  }
}
