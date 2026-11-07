import 'package:flutter/material.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';

/// CurrentMedicinesSection renders active prescriptions and dosage schedules or an empty state.
class CurrentMedicinesSection extends StatelessWidget {
  final String? medicineId;
  final String? medicineName;
  final String? timing;

  const CurrentMedicinesSection({
    super.key,
    this.medicineId,
    this.medicineName,
    this.timing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasMedicine = medicineName != null && medicineName!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Current medicines',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.pushGuarded(AppRoutes.medicines),
              child: Text(
                'View all >',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasMedicine)
          _buildEmptyState(context)
        else
          _buildMedicineCard(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(AppIcons.heart, size: 32, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'No active medicines added',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track your active prescriptions, dosage, and schedules.',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 180,
            height: 42,
            child: PrimaryButton(
              text: 'Add Medicine',
              onPressed: () => context.pushGuarded(AppRoutes.medicineAdd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subInfo = (timing != null && timing!.trim().isNotEmpty)
        ? timing!.trim()
        : 'Prescription active';

    return InkWell(
      onTap: () {
        if (medicineId != null && medicineId!.isNotEmpty) {
          context.pushGuarded(AppRoutes.medicineDetail(medicineId!));
        } else {
          context.pushGuarded(AppRoutes.medicines);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medicineName!,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subInfo,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
