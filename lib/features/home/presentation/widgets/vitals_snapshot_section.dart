import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../vitals/presentation/providers/measurement_providers.dart';
import '../../../vitals/presentation/screens/measurements_list_screen.dart';
import '../../data/models/home_summary_model.dart';

/// VitalsSnapshotSection renders recent vital signs readings in an adaptive grid.
class VitalsSnapshotSection extends ConsumerWidget {
  final List<VitalReadingSummary> vitals;

  const VitalsSnapshotSection({super.key, required this.vitals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Vitals snapshot',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.pushGuarded(AppRoutes.measurements),
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
        if (vitals.isEmpty)
          _buildEmptyState(context)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final isNarrow = constraints.maxWidth < 360;
              final crossAxisCount = isWide ? 4 : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: isNarrow ? 8 : 12,
                mainAxisSpacing: isNarrow ? 8 : 12,
                childAspectRatio: isWide
                    ? (constraints.maxWidth >= 800 ? 1.4 : 1.15)
                    : (isNarrow ? 0.95 : 1.15),
                children: vitals
                    .map(
                      (vital) => _buildVitalCard(
                        context,
                        ref,
                        vital,
                        isNarrow: isNarrow,
                      ),
                    )
                    .toList(),
              );
            },
          ),
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
          Icon(
            AppIcons.activity,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No vitals logged yet',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track your blood pressure, heart rate, and weight trends over time.',
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
              text: 'Log a reading',
              onPressed: () => context.pushGuarded(AppRoutes.measurementAdd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(
    BuildContext context,
    WidgetRef ref,
    VitalReadingSummary vital, {
    bool isNarrow = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semanticColors = context.semanticColors;

    Color iconBgColor = colorScheme.primaryContainer.withValues(alpha: 0.6);
    Color iconColor = colorScheme.primary;
    IconData icon = AppIcons.activity;

    if (vital.type == 'heart_rate') {
      iconBgColor = semanticColors.vitalHeartRateContainer;
      iconColor = semanticColors.vitalHeartRate;
      icon = AppIcons.heart;
    } else if (vital.type == 'spo2') {
      iconBgColor = semanticColors.successContainer;
      iconColor = semanticColors.success;
      icon = AppIcons.activity;
    } else if (vital.type == 'weight') {
      iconBgColor = semanticColors.vitalWeightContainer;
      iconColor = semanticColors.vitalWeight;
      icon = AppIcons.shield;
    }

    final isElevated = vital.status == 'ELEVATED';
    final chipBgColor = isElevated
        ? colorScheme.errorContainer
        : semanticColors.successContainer;
    final chipTextColor = isElevated
        ? colorScheme.error
        : semanticColors.success;

    return InkWell(
      onTap: () async {
        final activeProfile = ref.read(activeProfileProvider);
        if (activeProfile != null) {
          final repo = ref.read(measurementRepositoryProvider);
          final item = await repo.getMeasurementById(
            activeProfile.profileId,
            vital.id,
          );
          if (item != null && context.mounted) {
            showMeasurementDetailSheet(context, ref, item);
            return;
          }
        }
        if (context.mounted) {
          context.pushGuarded(AppRoutes.measurements);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 10 : 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          vital.value,
                          style: AppTypography.h1.copyWith(
                            fontSize: 18,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          vital.unit,
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        vital.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chipBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        vital.status,
                        style: AppTypography.caption.copyWith(
                          color: chipTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
