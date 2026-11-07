import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../data/models/medicine_model.dart';

class MedicineCardTile extends StatelessWidget {
  final MedicineModel medicine;

  const MedicineCardTile({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = medicine.isActive;

    final statusBgColor = isActive
        ? context.semanticColors.successContainer
        : colorScheme.surfaceContainerHighest;
    final statusTextColor = isActive
        ? context.semanticColors.success
        : colorScheme.onSurfaceVariant;

    final dosageFreq = [
      medicine.dosage,
      if (medicine.form != null && medicine.form!.isNotEmpty) medicine.form,
      if (medicine.frequency != null && medicine.frequency!.isNotEmpty)
        medicine.frequency,
    ].join(' · ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: colorScheme.outline),
      ),
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => context.pushGuarded(AppRoutes.medicineDetail(medicine.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.semanticColors.medicineAccentContainer,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Icon(
                      AppIcons.pill,
                      color: context.semanticColors.medicineAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.medicineName,
                          style: AppTypography.h3.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dosageFreq,
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      medicine.status,
                      style: AppTypography.caption.copyWith(
                        color: statusTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (medicine.linkedConsultationTitle != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: colorScheme.outline),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      AppIcons.fileText,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Prescribed at: ${medicine.linkedConsultationTitle}',
                        style: AppTypography.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
