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
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../timeline/presentation/widgets/timeline_connector.dart';
import '../../data/models/consultation_model.dart';
import '../providers/consultation_providers.dart';
import '../widgets/consultation_card_tile.dart';
import '../widgets/consultation_entrance_animator.dart';
import '../widgets/consultations_empty_state.dart';
import '../widgets/consultations_filter_header.dart';

/// ConsultationsListScreen displays profile-scoped clinical consultation records
/// with search, status filtering, sorting, and empty state management.
class ConsultationsListScreen extends ConsumerStatefulWidget {
  const ConsultationsListScreen({super.key});

  @override
  ConsumerState<ConsultationsListScreen> createState() =>
      _ConsultationsListScreenState();
}

class _ConsultationsListScreenState
    extends ConsumerState<ConsultationsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ConsultationFilter _filter = ConsultationFilter.all;
  ConsultationSort _sort = ConsultationSort.newest;
  DateRangeSelection _dateRange = const DateRangeSelection.allTime();
  bool _showCustomDatePanel = false;
  String? _lastProfileId;
  final Set<String> _animatedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _filter = ConsultationFilter.all;
      _sort = ConsultationSort.newest;
      _dateRange = const DateRangeSelection.allTime();
      _showCustomDatePanel = false;
    });
  }

  List<ConsultationModel> _applyFiltersAndSort(
    List<ConsultationModel> rawList,
  ) {
    final now = DateTime.now();

    var filtered = rawList.where((item) {
      // 1. Date Range Filter
      if (!_dateRange.isDateInRange(item.visitDate)) {
        return false;
      }

      // 2. Search Query Match
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final docMatch = item.doctorName.toLowerCase().contains(query);
        final hospMatch =
            item.hospitalName?.toLowerCase().contains(query) ?? false;
        final diagMatch = item.diagnosis.toLowerCase().contains(query);
        final complaintMatch = item.chiefComplaint.toLowerCase().contains(
          query,
        );
        final tagMatch = item.tags.any((t) => t.toLowerCase().contains(query));

        if (!docMatch &&
            !hospMatch &&
            !diagMatch &&
            !complaintMatch &&
            !tagMatch) {
          return false;
        }
      }

      // 3. Status Category Filter
      switch (_filter) {
        case ConsultationFilter.all:
          return true;
        case ConsultationFilter.upcomingFollowUp:
          return item.isFollowUpRequired &&
              !item.isFollowUpDone &&
              item.followUpDate != null &&
              item.followUpDate!.isAfter(now.subtract(const Duration(days: 1)));
        case ConsultationFilter.followUpDone:
          return item.isFollowUpRequired && item.isFollowUpDone;
        case ConsultationFilter.noFollowUp:
          return !item.isFollowUpRequired || item.followUpDate == null;
      }
    }).toList();

    // 4. Sorting
    filtered.sort((a, b) {
      if (_sort == ConsultationSort.newest) {
        return b.visitDate.compareTo(a.visitDate);
      } else {
        return a.visitDate.compareTo(b.visitDate);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider);
    if (_lastProfileId != activeProfile?.profileId) {
      _lastProfileId = activeProfile?.profileId;
      _animatedIds.clear();
    }

    final consultationsAsync = ref.watch(consultationsListNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.dashboard),
        ),
        title: Text(
          'Consultations',
          style: AppTypography.h1.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushGuarded(AppRoutes.addConsultation),
        icon: const Icon(AppIcons.calendar),
        label: const Text('Add Consultation'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header / Search & Filter Controls Bar
            ConsultationsFilterHeader(
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
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
              filter: _filter,
              onFilterChanged: (f) {
                setState(() => _filter = f);
              },
              sort: _sort,
              onSortChanged: (s) {
                setState(() => _sort = s);
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
            Divider(height: 1, color: colorScheme.outline),

            // Content List Body
            Expanded(
              child: consultationsAsync.when(
                loading: () => const Center(child: PulsingVaultLogo()),
                error: (err, stack) => AppErrorState(
                  error: err,
                  onRetry: () => ref.refresh(consultationsListNotifierProvider),
                ),
                data: (allConsultations) {
                  final filteredList = _applyFiltersAndSort(allConsultations);

                  if (allConsultations.isEmpty || filteredList.isEmpty) {
                    return ConsultationsEmptyState(
                      isCompletelyEmpty: allConsultations.isEmpty,
                      onClearFilters: _clearFilters,
                    );
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          final isFirst = index == 0;
                          final isLast = index == filteredList.length - 1;

                          return KeyedSubtree(
                            key: ValueKey<String>('consultation_${item.id}'),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TimelineConnector(
                                    icon: AppIcons.stethoscope,
                                    color: colorScheme.primary,
                                    showTopLine: !isFirst,
                                    showBottomLine: !isLast,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ConsultationEntranceAnimator(
                                      index: index,
                                      shouldAnimate: !_animatedIds.contains(
                                        item.id,
                                      ),
                                      onAnimationStarted: () =>
                                          _animatedIds.add(item.id),
                                      child: ConsultationCardTile(
                                        consultation: item,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
