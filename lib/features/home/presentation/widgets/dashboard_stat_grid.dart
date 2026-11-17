import 'package:material_ui/material_ui.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../data/models/home_summary_model.dart';

/// DashboardStatGrid renders top-level summary metrics (2x2 on mobile, 1x4 on wide displays).
class DashboardStatGrid extends StatelessWidget {
  final HomeSummaryModel summary;

  const DashboardStatGrid({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
              : (isNarrow ? 1.05 : 1.15),
          children: [
            _buildStatCard(
              context,
              title: 'CONSULTATIONS · TOTAL',
              count: summary.totalConsultations.toString(),
              icon: AppIcons.stethoscope,
              onTap: () => context.pushGuarded(AppRoutes.consultations),
              isNarrow: isNarrow,
            ),
            _buildStatCard(
              context,
              title: 'DOCTORS · SAVED',
              count: summary.totalDoctors.toString(),
              icon: AppIcons.userCheck,
              onTap: () => context.pushGuarded(AppRoutes.doctors),
              isNarrow: isNarrow,
            ),
            _buildStatCard(
              context,
              title: 'MEDICINES · ACTIVE',
              count: summary.totalMedicines.toString(),
              icon: AppIcons.heart,
              onTap: () => context.pushGuarded(AppRoutes.medicines),
              isNarrow: isNarrow,
            ),
            _buildStatCard(
              context,
              title: 'REPORTS · FILES',
              count: summary.totalReports.toString(),
              icon: AppIcons.fileText,
              onTap: () => context.pushGuarded(AppRoutes.reports),
              isNarrow: isNarrow,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String count,
    required IconData icon,
    required VoidCallback onTap,
    bool isNarrow = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 10 : 14),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    count,
                    style: AppTypography.display.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
