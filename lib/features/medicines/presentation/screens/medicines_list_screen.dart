import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../../shared/widgets/forms/custom_date_range_panel.dart';
import '../../data/models/medicine_model.dart';
import '../providers/medicine_providers.dart';
import '../widgets/medicine_card_tile.dart';
import '../widgets/medicines_empty_state.dart';
import '../widgets/medicines_filter_header.dart';

class MedicinesListScreen extends ConsumerStatefulWidget {
  const MedicinesListScreen({super.key});

  @override
  ConsumerState<MedicinesListScreen> createState() =>
      _MedicinesListScreenState();
}

class _MedicinesListScreenState extends ConsumerState<MedicinesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  MedicineFilter _selectedFilter = MedicineFilter.all;
  String _searchQuery = '';
  String _selectedSort = 'newest';
  DateRangeSelection _dateRange = const DateRangeSelection.allTime();
  bool _showCustomDatePanel = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MedicineModel> _filterMedicines(List<MedicineModel> allMedicines) {
    final filtered = allMedicines.where((medicine) {
      // Filter by status
      if (_selectedFilter == MedicineFilter.active && !medicine.isActive) {
        return false;
      }
      if (_selectedFilter == MedicineFilter.completed && medicine.isActive) {
        return false;
      }

      // Filter by date range (startDate)
      if (!_dateRange.isDateInRange(medicine.startDate)) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final nameMatch = medicine.medicineName.toLowerCase().contains(
          _searchQuery,
        );
        final notesMatch =
            medicine.notes?.toLowerCase().contains(_searchQuery) ?? false;
        final consultMatch =
            medicine.linkedConsultationTitle?.toLowerCase().contains(
              _searchQuery,
            ) ??
            false;
        if (!nameMatch && !notesMatch && !consultMatch) {
          return false;
        }
      }

      return true;
    }).toList();

    if (_selectedSort == 'oldest') {
      filtered.sort((a, b) => a.startDate.compareTo(b.startDate));
    } else {
      filtered.sort((a, b) => b.startDate.compareTo(a.startDate));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final medicinesAsync = ref.watch(medicinesListNotifierProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => context.popOrGo(AppRoutes.home),
        ),
        title: Text(
          'Medicines',
          style: AppTypography.h3.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushGuarded(AppRoutes.addMedicine),
        icon: const Icon(AppIcons.pill),
        label: const Text('Add Medicine'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Chips Header
            MedicinesFilterHeader(
              searchController: _searchController,
              searchQuery: _searchQuery,
              dateRange: _dateRange,
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
              selectedSort: _selectedSort,
              onSortChanged: (sort) {
                setState(() => _selectedSort = sort);
              },
              selectedFilter: _selectedFilter,
              onFilterChanged: (f) {
                setState(() => _selectedFilter = f);
              },
            ),
            if (_showCustomDatePanel) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: CustomDateRangePanel(
                  initialStartDate: _dateRange.customStart,
                  initialEndDate: _dateRange.customEnd,
                  onApply: (start, end) {
                    setState(() {
                      _dateRange = DateRangeSelection.custom(start, end);
                      _showCustomDatePanel = false;
                    });
                  },
                  onCancel: () {
                    setState(() => _showCustomDatePanel = false);
                  },
                ),
              ),
            ],

            // Content Area
            Expanded(
              child: medicinesAsync.when(
                loading: () => const Center(child: PulsingVaultLogo()),
                error: (err, stack) => AppErrorState(
                  error: err,
                  onRetry: () => ref
                      .read(medicinesListNotifierProvider.notifier)
                      .refresh(),
                ),
                data: (allMedicines) {
                  final filtered = _filterMedicines(allMedicines);

                  // State A: No medicines exist for active profile at all
                  if (allMedicines.isEmpty) {
                    return const MedicinesEmptyState(
                      title: 'No medicines added yet.',
                      subtitle: 'Track your prescriptions and active medications securely.',
                    );
                  }

                  // State B: Medicines exist, but filter/search yielded 0 matches
                  if (filtered.isEmpty) {
                    return MedicinesEmptyState(
                      title: 'No medicines match your filters.',
                      subtitle: 'Try adjusting your search terms or filter selection.',
                      buttonText: 'Clear Filters',
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _selectedFilter = MedicineFilter.all;
                        });
                      },
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(medicinesListNotifierProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final medicine = filtered[index];
                        return MedicineCardTile(medicine: medicine);
                      },
                    ),
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
