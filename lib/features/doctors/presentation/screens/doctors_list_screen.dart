import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medivalut/app/routes/app_routes.dart';
import 'package:medivalut/core/constants/app_icons.dart';
import 'package:medivalut/core/constants/app_spacing.dart';
import 'package:medivalut/core/constants/app_typography.dart';
import 'package:medivalut/core/extensions/build_context_extensions.dart';
import 'package:medivalut/features/doctors/presentation/providers/doctors_providers.dart';
import 'package:medivalut/features/doctors/presentation/widgets/doctor_card.dart';
import 'package:medivalut/shared/widgets/buttons/sort_toggle_button.dart';
import 'package:medivalut/shared/widgets/feedback/app_empty_state.dart';
import 'package:medivalut/shared/widgets/feedback/app_error_state.dart';
import 'package:medivalut/shared/widgets/feedback/pulsing_vault_logo.dart';
import 'package:medivalut/shared/widgets/forms/app_search_field.dart';

/// DoctorsListScreen presents the profile-scoped doctor directory
/// with live search, dynamic counts, and Material 3 empty states.
class DoctorsListScreen extends ConsumerStatefulWidget {
  const DoctorsListScreen({super.key});

  @override
  ConsumerState<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends ConsumerState<DoctorsListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(doctorSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDoctorsAsync = ref.watch(filteredDoctorsProvider);
    final allDoctorsAsync = ref.watch(doctorsListProvider);
    final searchQuery = ref.watch(doctorSearchQueryProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Doctors',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.dashboard),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushGuarded(AppRoutes.doctorAdd),
        icon: const Icon(AppIcons.stethoscope),
        label: const Text('Add Doctor'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  // 1. Search Bar
                  AppSearchField(
                    controller: _searchController,
                    hintText: 'Search name, specialty, clinic...',
                    onChanged: (val) {
                      ref.read(doctorSearchQueryProvider.notifier).state = val;
                    },
                    onClear: () {
                      _searchController.clear();
                      ref.read(doctorSearchQueryProvider.notifier).state = '';
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Count + Sort Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: allDoctorsAsync.when(
                          data: (all) {
                            final total = all.length;
                            final filtered =
                                filteredDoctorsAsync.valueOrNull?.length ??
                                total;
                            final label = searchQuery.isNotEmpty
                                ? '$filtered of $total doctors'
                                : '$total doctors';
                            return Text(
                              label,
                              style: AppTypography.subtitle.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (err, stack) => const SizedBox.shrink(),
                        ),
                      ),
                      SortToggleButton(
                        currentSort: ref.watch(doctorSortProvider),
                        options: const [
                          SortOptionItem(
                            value: 'newest',
                            label: 'Newest first',
                          ),
                          SortOptionItem(
                            value: 'oldest',
                            label: 'Oldest first',
                          ),
                          SortOptionItem(
                            value: 'alphabetical',
                            label: 'Alphabetical (A-Z)',
                          ),
                        ],
                        onSortChanged: (sort) {
                          ref.read(doctorSortProvider.notifier).state = sort;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 3. Doctor List / Empty State
                  Expanded(
                    child: filteredDoctorsAsync.when(
                      loading: () => const Center(child: PulsingVaultLogo()),
                      error: (err, stack) => AppErrorState(
                        error: err,
                        title: 'Failed to load doctors directory',
                        onRetry: () =>
                            ref.read(doctorsListProvider.notifier).refresh(),
                      ),
                      data: (doctors) {
                        if (doctors.isEmpty) {
                          if (searchQuery.isNotEmpty) {
                            return _buildSearchEmptyState(context);
                          }
                          return _buildEmptyState(context);
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: doctors.length,
                          itemBuilder: (context, index) {
                            final doctor = doctors[index];
                            return DoctorCard(
                              doctor: doctor,
                              onTap: () => context.pushGuarded(
                                AppRoutes.doctorProfile(doctor.id),
                              ),
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.stethoscope,
      title: 'No doctors added yet',
      message:
          'Add your doctors, clinics, and specialists to keep your medical history organized.',
    );
  }

  Widget _buildSearchEmptyState(BuildContext context) {
    return AppEmptyState.filtered(
      icon: AppIcons.search,
      title: 'No matching doctors found',
      message: 'Try searching for another name or specialty.',
      actionLabel: 'Clear search',
      actionIcon: null,
      onAction: () {
        _searchController.clear();
        ref.read(doctorSearchQueryProvider.notifier).state = '';
      },
    );
  }
}
