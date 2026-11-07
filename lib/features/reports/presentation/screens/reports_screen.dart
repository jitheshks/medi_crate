import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../shared/widgets/buttons/date_range_filter_button.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/forms/custom_date_range_panel.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/reports_providers.dart';
import '../widgets/report_empty_state.dart';
import '../widgets/report_list_tile.dart';
import '../widgets/report_skeleton_loading.dart';
import '../widgets/reports_category_chips.dart';
import '../widgets/reports_header_section.dart';
import '../widgets/reports_search_bar.dart';
import '../widgets/reports_sort_dropdown.dart';

/// ReportsScreen renders the primary diagnostic reports list, live search, filter chips,
/// sort options, and month-year grouped cards.
class ReportsScreen extends ConsumerStatefulWidget {
  /// When true, renders a standalone AppBar (back arrow + "Reports" title +
  /// Upload action) for the pushed `/reports` route. Defaults to false so the
  /// Dashboard bottom-navigation tab keeps its bare embedded presentation.
  final bool showStandaloneAppBar;

  const ReportsScreen({super.key, this.showStandaloneAppBar = false});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _showCustomDatePanel = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(reportSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider);
    final totalCount = ref.watch(totalReportsCountProvider);
    final filteredCount = ref.watch(filteredReportsCountProvider);
    final selectedCategory = ref.watch(reportFilterCategoryProvider);
    final dateRange = ref.watch(reportDateRangeProvider);
    final selectedSort = ref.watch(reportSortOptionProvider);
    final searchQuery = ref.watch(reportSearchQueryProvider);
    final groupedAsync = ref.watch(groupedReportsProvider);

    if (_searchController.text != searchQuery) {
      _searchController.value = _searchController.value.copyWith(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
        composing: TextRange.empty,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.showStandaloneAppBar
          ? AppBar(
              backgroundColor: colorScheme.surface,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                onPressed: () => context.popOrGo(AppRoutes.dashboard),
              ),
              title: Text(
                'Reports',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushGuarded(AppRoutes.addReport),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Report'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final horizontalPadding = isWide ? 24.0 : 16.0;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: SingleChildScrollView(
                key: const PageStorageKey('reports_screen_scroll_key'),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReportsHeaderSection(
                      filteredCount: filteredCount,
                      totalCount: totalCount,
                    ),
                    const SizedBox(height: 16),

                    // Search Bar
                    ReportsSearchBar(
                      controller: _searchController,
                      onChanged: (val) {
                        ref.read(reportSearchQueryProvider.notifier).state =
                            val;
                      },
                      onClear: () {
                        ref.read(reportSearchQueryProvider.notifier).state = '';
                      },
                    ),
                    const SizedBox(height: 14),

                    // Filter Chips (Horizontal Scroll)
                    ReportsCategoryChips(
                      selectedCategory: selectedCategory,
                      onCategorySelected: (cat) {
                        ref.read(reportFilterCategoryProvider.notifier).state =
                            cat;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Date Range & Sort Dropdown Bar
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        DateRangeFilterButton(
                          selection:
                              dateRange ?? const DateRangeSelection.allTime(),
                          onSelected: (preset) {
                            if (preset == DateRangePreset.custom) {
                              setState(() {
                                _showCustomDatePanel = true;
                              });
                            } else {
                              setState(() {
                                _showCustomDatePanel = false;
                              });
                              ref.read(reportDateRangeProvider.notifier).state =
                                  DateRangeSelection.preset(preset);
                            }
                          },
                        ),
                        ReportsSortDropdown(
                          selectedSort: selectedSort,
                          onSortSelected: (option) {
                            ref.read(reportSortOptionProvider.notifier).state =
                                option;
                          },
                        ),
                        Text(
                          'Grouped by Month',
                          style: AppTypography.labelMedium.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_showCustomDatePanel) ...[
                      const SizedBox(height: 8),
                      CustomDateRangePanel(
                        initialStartDate: dateRange?.customStart,
                        initialEndDate: dateRange?.customEnd,
                        onApply: (start, end) {
                          setState(() {
                            _showCustomDatePanel = false;
                          });
                          ref.read(reportDateRangeProvider.notifier).state =
                              DateRangeSelection.custom(start, end);
                        },
                        onCancel: () {
                          setState(() {
                            _showCustomDatePanel = false;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Grouped List or Empty / Loading state
                    groupedAsync.when(
                      data: (groupedMap) {
                        if (groupedMap.isEmpty) {
                          final isFiltered =
                              searchQuery.isNotEmpty ||
                              selectedCategory.toUpperCase() != 'ALL';

                          return ReportEmptyState(
                            title: isFiltered
                                ? 'No matching diagnostic reports'
                                : 'No diagnostic reports saved yet.',
                            subtitle: isFiltered
                                ? 'Try adjusting your search terms or filter chips.'
                                : 'Lab tests, imaging scans, and prescriptions for ${activeProfile?.fullName ?? "this profile"} will appear here.',
                            actionLabel: isFiltered ? 'Clear filters' : null,
                            onAction: isFiltered
                                ? () {
                                    ref
                                            .read(
                                              reportSearchQueryProvider
                                                  .notifier,
                                            )
                                            .state =
                                        '';
                                    ref
                                            .read(
                                              reportFilterCategoryProvider
                                                  .notifier,
                                            )
                                            .state =
                                        'ALL';
                                  }
                                : null,
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: groupedMap.entries.map((entry) {
                            final monthKey = entry.key;
                            final reportsInGroup = entry.value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    bottom: 10,
                                    top: 10,
                                  ),
                                  child: Text(
                                    monthKey,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                ...reportsInGroup.map(
                                  (report) => ReportListTile(report: report),
                                ),
                              ],
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const ReportSkeletonLoading(),
                      error: (err, stack) => AppErrorState(
                        error: err,
                        onRetry: () {
                          ref
                              .read(reportsListNotifierProvider.notifier)
                              .refreshReports();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (widget.showStandaloneAppBar) {
      final canPop = ModalRoute.of(context)?.canPop ?? false;
      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            context.popOrGo(AppRoutes.dashboard);
          }
        },
        child: scaffold,
      );
    }

    return scaffold;
  }
}
