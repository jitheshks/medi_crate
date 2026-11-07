import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../../shared/widgets/forms/custom_date_range_panel.dart';
import '../providers/measurement_providers.dart';
import '../widgets/measurement_card_tile.dart';
import '../widgets/measurement_detail_sheet.dart';
import '../widgets/measurements_search_bar.dart';
import '../widgets/vitals_controls_bar.dart';
import '../widgets/vitals_empty_states.dart';
import '../widgets/vitals_list_filter_helper.dart';

export '../widgets/measurement_detail_sheet.dart'
    show showMeasurementDetailSheet;

/// MeasurementsListScreen presents day-grouped health measurements history
/// with reactive search, vital type filtering, sorting, and active profile scoping.
class MeasurementsListScreen extends ConsumerStatefulWidget {
  const MeasurementsListScreen({super.key});

  @override
  ConsumerState<MeasurementsListScreen> createState() =>
      _MeasurementsListScreenState();
}

class _MeasurementsListScreenState
    extends ConsumerState<MeasurementsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilterType = 'All';
  String _selectedSortOrder = 'Newest first';
  DateRangeSelection _dateRange = const DateRangeSelection.allTime();
  bool _showCustomDatePanel = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final measurementsAsync = ref.watch(measurementsListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.home),
        ),
        title: Text(
          'Health Measurements',
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
            tooltip: 'Refresh measurements',
            onPressed: () {
              ref.read(measurementsListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushGuarded(AppRoutes.addMeasurement),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: const CircleBorder(),
        elevation: 4,
        tooltip: 'Add measurement',
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            MeasurementsSearchBar(
              searchController: _searchController,
              selectedFilterType: _selectedFilterType,
              onFilterSelected: (type) {
                setState(() => _selectedFilterType = type);
              },
              onSearchChanged: () => setState(() {}),
              onClearSearch: () {
                _searchController.clear();
                setState(() {});
              },
            ),
            Expanded(
              child: measurementsAsync.when(
                loading: () => const Center(child: PulsingVaultLogo()),
                error: (err, stack) => AppErrorState(
                  error: err,
                  onRetry: () =>
                      ref.read(measurementsListProvider.notifier).refresh(),
                ),
                data: (allMeasurements) {
                  if (allMeasurements.isEmpty) {
                    return const VitalsEmptyState();
                  }

                  final filtered = VitalsListFilterHelper.applyFilters(
                    list: allMeasurements,
                    query: _searchController.text,
                    selectedFilterType: _selectedFilterType,
                    dateRange: _dateRange,
                  );

                  if (filtered.isEmpty) {
                    return VitalsFilteredEmptyState(
                      onClearFilters: () {
                        _searchController.clear();
                        setState(() {
                          _selectedFilterType = 'All';
                        });
                      },
                    );
                  }

                  VitalsListFilterHelper.applySorting(
                    list: filtered,
                    sortOrder: _selectedSortOrder,
                  );

                  final grouped = VitalsListFilterHelper.groupByDate(filtered);

                  return Column(
                    children: [
                      VitalsControlsBar(
                        dateRange: _dateRange,
                        selectedSortOrder: _selectedSortOrder,
                        filteredCount: filtered.length,
                        totalCount: allMeasurements.length,
                        onDateRangePresetSelected: (preset) {
                          if (preset == DateRangePreset.custom) {
                            setState(() => _showCustomDatePanel = true);
                          } else {
                            setState(() {
                              _showCustomDatePanel = false;
                              _dateRange = DateRangeSelection.preset(preset);
                            });
                          }
                        },
                        onSortOrderSelected: (order) {
                          setState(() => _selectedSortOrder = order);
                        },
                      ),
                      if (_showCustomDatePanel) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: CustomDateRangePanel(
                            initialStartDate: _dateRange.customStart,
                            initialEndDate: _dateRange.customEnd,
                            onApply: (start, end) {
                              setState(() {
                                _dateRange = DateRangeSelection.custom(
                                  start,
                                  end,
                                );
                                _showCustomDatePanel = false;
                              });
                            },
                            onCancel: () {
                              setState(() => _showCustomDatePanel = false);
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          key: const PageStorageKey(
                            'measurements_list_scroll_key',
                          ),
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 80,
                          ),
                          itemCount: grouped.keys.length,
                          itemBuilder: (context, index) {
                            final dateKey = grouped.keys.elementAt(index);
                            final dayItems = grouped[dateKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 16,
                                    bottom: 10,
                                    left: 4,
                                  ),
                                  child: Text(
                                    dateKey.toUpperCase(),
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                ...dayItems.map(
                                  (item) => MeasurementCardTile(
                                    item: item,
                                    onTap: () => showMeasurementDetailSheet(
                                      context,
                                      ref,
                                      item,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
