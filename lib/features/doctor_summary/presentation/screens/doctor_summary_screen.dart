import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../data/models/doctor_summary_model.dart';
import '../providers/doctor_summary_providers.dart';
import '../widgets/doctor_summary_bottom_bar.dart';
import '../widgets/doctor_summary_category_section.dart';
import '../widgets/doctor_summary_consultation_focus_card.dart';
import '../widgets/doctor_summary_date_filter_card.dart';
import '../widgets/doctor_summary_patient_header.dart';

/// DoctorSummaryScreen provides a customizable, physician-oriented health summary
/// combining date filtering, consultation focusing, and granular category selection.
class DoctorSummaryScreen extends ConsumerWidget {
  const DoctorSummaryScreen({super.key});

  void _onDatePresetChanged(
    WidgetRef ref,
    DoctorSummaryDatePreset preset,
    DoctorSummaryModel baseSummary,
  ) {
    ref.read(doctorSummaryDatePresetProvider.notifier).state = preset;
    if (preset != DoctorSummaryDatePreset.custom) {
      ref.read(doctorSummaryCustomDateRangeProvider.notifier).state = null;
    }
    final effectiveRange = ref.read(doctorSummaryEffectiveDateRangeProvider);
    final repo = ref.read(doctorSummaryRepositoryProvider);
    final filtered = repo.filterSummaryByDate(
      baseSummary,
      dateRange: effectiveRange,
      dateRangeLabel: ref.read(doctorSummaryDateRangeLabelProvider),
    );
    ref
        .read(doctorSummaryDeselectedItemIdsProvider.notifier)
        .pruneIneligible(getEligibleItemIds(filtered));
  }

  Future<void> _pickCustomDateRange(
    BuildContext context,
    WidgetRef ref,
    DoctorSummaryModel baseSummary,
  ) async {
    final currentRange = ref.read(doctorSummaryCustomDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange:
          currentRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      ref.read(doctorSummaryCustomDateRangeProvider.notifier).state = picked;
      _onDatePresetChanged(ref, DoctorSummaryDatePreset.custom, baseSummary);
    }
  }

  void _selectAll(WidgetRef ref) {
    ref.read(doctorSummarySelectedCategoriesProvider.notifier).selectAll();
    ref.read(doctorSummaryDeselectedItemIdsProvider.notifier).clear();
  }

  void _clearAll(WidgetRef ref) {
    ref.read(doctorSummarySelectedCategoriesProvider.notifier).clearAll();
    ref.read(doctorSummaryDeselectedItemIdsProvider.notifier).clear();
  }

  void _toggleCategory(
    WidgetRef ref,
    DoctorSummaryCategory category,
    bool? currentTristate,
    List<Map<String, dynamic>> items,
  ) {
    final selectedCategories = ref.read(
      doctorSummarySelectedCategoriesProvider,
    );
    final isCategorySelected = selectedCategories.contains(category);

    if (currentTristate == true) {
      // Unselect category entirely
      ref
          .read(doctorSummarySelectedCategoriesProvider.notifier)
          .toggleCategory(category, false);
      for (final item in items) {
        final id = getSummaryItemId(item, category);
        ref
            .read(doctorSummaryDeselectedItemIdsProvider.notifier)
            .toggleItem(id, false);
      }
    } else {
      // Select category fully
      if (!isCategorySelected) {
        ref
            .read(doctorSummarySelectedCategoriesProvider.notifier)
            .toggleCategory(category, true);
      }
      for (final item in items) {
        final id = getSummaryItemId(item, category);
        ref
            .read(doctorSummaryDeselectedItemIdsProvider.notifier)
            .toggleItem(id, true);
      }
    }
  }

  void _toggleItem(
    WidgetRef ref,
    String itemId,
    bool isSelected,
    DoctorSummaryCategory category,
  ) {
    final selectedCategories = ref.read(
      doctorSummarySelectedCategoriesProvider,
    );
    if (!selectedCategories.contains(category) && isSelected) {
      ref
          .read(doctorSummarySelectedCategoriesProvider.notifier)
          .toggleCategory(category, true);
    }
    ref
        .read(doctorSummaryDeselectedItemIdsProvider.notifier)
        .toggleItem(itemId, isSelected);
  }

  void _toggleConsultation(WidgetRef ref, String id, bool isSelected) {
    final current = Set<String>.from(
      ref.read(doctorSummarySelectedConsultationIdsProvider),
    );
    if (isSelected) {
      current.add(id);
    } else {
      current.remove(id);
    }
    ref.read(doctorSummarySelectedConsultationIdsProvider.notifier).state =
        current;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseSummaryAsync = ref.watch(baseDoctorSummaryProvider);
    final combinedSummaryAsync = ref.watch(
      combinedFilteredDoctorSummaryProvider,
    );
    final customizedSummaryAsync = ref.watch(doctorSummaryProvider);
    final selectedCount = ref.watch(doctorSummarySelectedCountProvider);
    final datePreset = ref.watch(doctorSummaryDatePresetProvider);
    final dateLabel = ref.watch(doctorSummaryDateRangeLabelProvider);
    final selectedConsultationIds = ref.watch(
      doctorSummarySelectedConsultationIdsProvider,
    );
    final selectedCategories = ref.watch(
      doctorSummarySelectedCategoriesProvider,
    );
    final deselectedIds = ref.watch(doctorSummaryDeselectedItemIdsProvider);
    final customDateRange = ref.watch(doctorSummaryCustomDateRangeProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(
          color: colorScheme.onSurface,
          onPressed: () => context.popOrGo(AppRoutes.dashboard),
        ),
        title: Text(
          'Share with Doctor',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        centerTitle: false,
      ),
      body: baseSummaryAsync.when(
        loading: () => const Center(child: PulsingVaultLogo()),
        error: (err, _) => AppErrorState(
          error: err,
          onRetry: () => ref.refresh(baseDoctorSummaryProvider),
        ),
        data: (baseSummary) {
          if (baseSummary == null) {
            return const Center(child: Text('No active profile selected.'));
          }

          final combinedSummary = combinedSummaryAsync.value ?? baseSummary;
          final customizedSummary =
              customizedSummaryAsync.value ?? combinedSummary;
          final p = baseSummary.profile;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.refresh(baseDoctorSummaryProvider),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Patient Profile & Demographics Card
                        DoctorSummaryPatientHeader(
                          summary: baseSummary,
                          dateLabel: dateLabel,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // 2. DATE FILTER Section
                        DoctorSummaryDateFilterCard(
                          selectedPreset: datePreset,
                          customDateRange: customDateRange,
                          onPresetSelected: (preset) =>
                              _onDatePresetChanged(ref, preset, baseSummary),
                          onPickCustomRange: () =>
                              _pickCustomDateRange(context, ref, baseSummary),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // 3. FOCUS ON A SPECIFIC CONSULTATION Card
                        DoctorSummaryConsultationFocusCard(
                          consultations: baseSummary.consultations,
                          selectedConsultationIds: selectedConsultationIds,
                          onToggleConsultation: (id, isSelected) =>
                              _toggleConsultation(ref, id, isSelected),
                          onSelectAll: () {
                            final allIds = baseSummary.consultations
                                .map(
                                  (c) =>
                                      c['id']?.toString() ??
                                      c['uuid']?.toString() ??
                                      '',
                                )
                                .where((id) => id.isNotEmpty)
                                .toSet();
                            applyMultipleConsultationFocus(
                              ref: ref,
                              baseModel: baseSummary,
                              consultationIds: allIds,
                            );
                          },
                          onClearAll: () {
                            applyMultipleConsultationFocus(
                              ref: ref,
                              baseModel: baseSummary,
                              consultationIds: <String>{},
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // 4. CUSTOMIZE CONTENT Section with Category Rows & Disclaimer
                        DoctorSummaryCategorySection(
                          combinedSummary: combinedSummary,
                          selectedCategories: selectedCategories,
                          deselectedIds: deselectedIds,
                          onSelectAll: () => _selectAll(ref),
                          onClearAll: () => _clearAll(ref),
                          onToggleCategory: (category, tristate, items) =>
                              _toggleCategory(ref, category, tristate, items),
                          onToggleItem: (itemId, isSelected, category) =>
                              _toggleItem(ref, itemId, isSelected, category),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Sticky Bottom Action Buttons
              DoctorSummaryBottomBar(
                selectedCount: selectedCount,
                summary: customizedSummary,
                profile: p,
                dateLabel: dateLabel,
              ),
            ],
          );
        },
      ),
    );
  }
}
