import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../../shared/widgets/forms/custom_date_range_panel.dart';
import '../../data/models/appointment_model.dart';
import '../providers/appointment_providers.dart';
import '../widgets/appointment_card_tile.dart';
import '../widgets/appointments_empty_state.dart';
import '../widgets/appointments_filter_header.dart';

/// AppointmentsListScreen renders profile-scoped appointments organized by status tabs.
class AppointmentsListScreen extends ConsumerStatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  ConsumerState<AppointmentsListScreen> createState() =>
      _AppointmentsListScreenState();
}

class _AppointmentsListScreenState
    extends ConsumerState<AppointmentsListScreen> {
  String _selectedTab =
      'upcoming'; // 'upcoming', 'completed', 'cancelled', 'all'
  String _searchQuery = '';
  String _selectedSort = 'newest';
  DateRangeSelection _dateRange = const DateRangeSelection.allTime();
  bool _showCustomDatePanel = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppointmentModel> _filterAppointments(List<AppointmentModel> all) {
    var filtered = all
        .where((item) {
          if (_selectedTab == 'upcoming') return item.isUpcoming;
          if (_selectedTab == 'completed') return item.isCompleted;
          if (_selectedTab == 'cancelled') {
            return item.isCancelled || item.isMissed;
          }
          return true;
        })
        .where((item) {
          return _dateRange.isDateInRange(item.date);
        })
        .toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return item.title.toLowerCase().contains(q) ||
            item.doctorName.toLowerCase().contains(q) ||
            (item.hospitalName != null &&
                item.hospitalName!.toLowerCase().contains(q)) ||
            (item.department != null &&
                item.department!.toLowerCase().contains(q));
      }).toList();
    }

    if (_selectedSort == 'oldest') {
      filtered.sort((a, b) => a.date.compareTo(b.date));
    } else {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    }
    return filtered;
  }

  Map<String, List<AppointmentModel>> _groupAppointmentsByDay(
    List<AppointmentModel> list,
  ) {
    final Map<String, List<AppointmentModel>> groups = {};
    final dateFormat = DateFormat('EEEE d MMMM yyyy');

    for (final app in list) {
      final key = dateFormat.format(app.date).toUpperCase();
      groups.putIfAbsent(key, () => []).add(app);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(appointmentsListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.home),
        ),
        title: Text(
          'Appointments',
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: () {
              ref.read(appointmentsListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushGuarded(AppRoutes.newAppointment),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Search & Filter Header
                AppointmentsFilterHeader(
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
                  selectedSort: _selectedSort,
                  onSortChanged: (sort) {
                    setState(() => _selectedSort = sort);
                  },
                  selectedTab: _selectedTab,
                  onTabSelected: (tab) {
                    setState(() => _selectedTab = tab);
                  },
                ),
                if (_showCustomDatePanel) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
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
                const SizedBox(height: 8),

                // Appointments Body
                Expanded(
                  child: appointmentsAsync.when(
                    loading: () => const Center(child: PulsingVaultLogo()),
                    error: (err, stack) => AppErrorState(
                      error: err,
                      onRetry: () =>
                          ref.read(appointmentsListProvider.notifier).refresh(),
                    ),
                    data: (allAppointments) {
                      final filtered = _filterAppointments(allAppointments);

                      if (filtered.isEmpty) {
                        return AppointmentsEmptyState(
                          isCompletelyEmpty: allAppointments.isEmpty,
                          onClear: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedTab = 'upcoming';
                              _dateRange = const DateRangeSelection.allTime();
                            });
                          },
                        );
                      }

                      final grouped = _groupAppointmentsByDay(filtered);

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        itemCount: grouped.keys.length,
                        itemBuilder: (context, index) {
                          final dayHeader = grouped.keys.elementAt(index);
                          final dayItems = grouped[dayHeader]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Group Date Header
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 14,
                                  bottom: 8,
                                ),
                                child: Text(
                                  dayHeader,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    fontSize: 11,
                                  ),
                                ),
                              ),

                              // Day Appointments Cards
                              ...dayItems.map(
                                (app) => AppointmentCardTile(app: app),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
