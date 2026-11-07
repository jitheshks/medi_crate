import 'package:flutter/material.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/models/ocr_medicine_item_draft.dart';
import 'ocr_medicine_draft_tile.dart';

class OcrExtractedMedicinesSection extends StatelessWidget {
  final List<OcrMedicineItemDraft> medicines;
  final VoidCallback onAddMedicine;
  final ValueChanged<OcrMedicineItemDraft> onUpdateMedicine;
  final ValueChanged<String> onRemoveMedicine;

  const OcrExtractedMedicinesSection({
    super.key,
    required this.medicines,
    required this.onAddMedicine,
    required this.onUpdateMedicine,
    required this.onRemoveMedicine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Extracted Medicines (${medicines.length})',
              style: AppTypography.h3.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: onAddMedicine,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (medicines.isEmpty)
          Text(
            'No specific medicine items detected. You can add items manually above.',
            style: AppTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...medicines.map(
            (med) => OcrMedicineDraftTile(
              item: med,
              onChanged: onUpdateMedicine,
              onDelete: () => onRemoveMedicine(med.id),
            ),
          ),
      ],
    );
  }
}
