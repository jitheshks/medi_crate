import 'package:flutter/material.dart';

import '../../../../../core/constants/app_typography.dart';
import '../../../../../shared/widgets/forms/custom_text_field.dart';
import '../../../data/models/measurement_model.dart';

class MeasurementNotesSourceSection extends StatelessWidget {
  final TextEditingController notesController;
  final String selectedType;

  const MeasurementNotesSourceSection({
    super.key,
    required this.notesController,
    required this.selectedType,
  });

  @override
  Widget build(BuildContext context) {
    final isBmi = selectedType == MeasurementTypes.bmi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Notes optional',
          child: CustomTextField(
            controller: notesController,
            label: 'NOTES (OPTIONAL)',
            hint: isBmi ? 'e.g. After workout' : 'Context for this reading...',
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isBmi ? 'Source will be recorded as Calculated from profile.' : 'Source will be recorded as Manual. Device and import sources will sync automatically once those integrations are connected.',
          style: AppTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
