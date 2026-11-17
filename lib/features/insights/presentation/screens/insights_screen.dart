import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/insights_providers.dart';
import '../widgets/detailed_activity_sections.dart';
import '../widgets/expense_analytics_section.dart';
import '../widgets/health_score_card.dart';
import '../widgets/healthcare_activity_grid.dart';
import '../widgets/insights_skeleton_loading.dart';
import '../widgets/insights_time_filter_chips.dart';
import '../widgets/vitals_analysis_section.dart';

/// InsightsScreen presents automated health trends, vitals overview,
/// vitals analysis charts, healthcare activity, and expense analytics scoped to active profile.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfile = ref.watch(activeProfileProvider);
    final insightsState = ref.watch(insightsSummaryProvider);
    final appCurrency = ref.watch(appCurrencyProvider);

    final profileName = activeProfile?.fullName ?? 'My Profile';
    final relationship = activeProfile?.relationship ?? 'Self';

    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1024),
        child: insightsState.when(
          skipLoadingOnReload: true,
          loading: () => const InsightsSkeletonLoading(),
          error: (error, stackTrace) => AppErrorState(
            error: error,
            title: 'Failed to load insights for $profileName',
            onRetry: () => ref.read(insightsSummaryProvider.notifier).refresh(),
          ),
          data: (summary) {
            return SingleChildScrollView(
              key: const PageStorageKey('insights_tab_scroll_key'),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INSIGHTS',
                              style: AppTypography.caption.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Health Analytics',
                              style: AppTypography.h1.copyWith(
                                fontSize: 24,
                                color: colorScheme.onSurface,
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
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$relationship: $profileName',
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Understand trends and spending across your health record.',
                    style: AppTypography.subtitle.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 2. Time Range Filter Chips
                  const InsightsTimeFilterChips(),

                  const SizedBox(height: AppSpacing.lg),

                  // 3. Health Record Score Hero Card
                  HealthScoreCard(summary: summary),

                  const SizedBox(height: AppSpacing.xl),

                  // 4. Score Breakdown Section
                  ScoreBreakdownSection(vaultScore: summary.vaultScore),

                  const SizedBox(height: AppSpacing.xl),

                  // 5. See What's Missing Section
                  SeeWhatsMissingSection(summary: summary),

                  const SizedBox(height: AppSpacing.xl),

                  // 6. Vitals Analysis Section (Real historical measurements & trend charts)
                  VitalsAnalysisSection(trends: summary.vitalTrends),

                  const SizedBox(height: AppSpacing.xl),

                  // 7. Healthcare Activity Summary Grid
                  Text(
                    'Healthcare activity',
                    style: AppTypography.h3.copyWith(
                      fontSize: 17,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  HealthcareActivityGrid(summary: summary),

                  const SizedBox(height: AppSpacing.xl),

                  // 8. Detailed Activity Cards (Consultations, Appointments, Medicines, Reports, Care Directory)
                  DetailedActivitySections(summary: summary),

                  const SizedBox(height: AppSpacing.xl),

                  // 9. Total Healthcare Expense Analytics Section
                  ExpenseAnalyticsSection(
                    summary: summary,
                    currency: appCurrency,
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // 10. Live Data Disclaimer Footnote
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        'Every number above is computed live from your Consultations, Appointments, Reports, Measurements, and Expenses — nothing here is a separate or duplicated dataset.',
                        style: AppTypography.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
