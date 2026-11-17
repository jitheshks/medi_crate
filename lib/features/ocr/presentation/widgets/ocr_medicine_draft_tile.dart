import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/models/ocr_medicine_item_draft.dart';

/// Interactive tile widget for reviewing and editing an extracted medicine item draft.
class OcrMedicineDraftTile extends StatelessWidget {
  final OcrMedicineItemDraft item;
  final ValueChanged<OcrMedicineItemDraft> onChanged;
  final VoidCallback onDelete;

  const OcrMedicineDraftTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.medicationName,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name',
                    isDense: true,
                  ),
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  onChanged: (val) =>
                      onChanged(item.copyWith(medicationName: val)),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: onDelete,
                tooltip: 'Remove Medication',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.dosage,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (e.g. 500mg)',
                    isDense: true,
                  ),
                  onChanged: (val) => onChanged(item.copyWith(dosage: val)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency (e.g. Twice daily)',
                    isDense: true,
                  ),
                  onChanged: (val) => onChanged(item.copyWith(frequency: val)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
