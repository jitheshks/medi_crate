import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_crate/app/routes/app_routes.dart';
import 'package:medi_crate/core/constants/app_icons.dart';
import 'package:medi_crate/core/constants/app_spacing.dart';
import 'package:medi_crate/core/constants/app_typography.dart';
import 'package:medi_crate/core/extensions/build_context_extensions.dart';
import 'package:medi_crate/core/theme/app_semantic_colors.dart';
import 'package:medi_crate/features/hospitals/presentation/providers/hospitals_providers.dart';
import 'package:medi_crate/features/hospitals/presentation/widgets/hospital_card.dart';
import 'package:medi_crate/shared/widgets/buttons/sort_toggle_button.dart';
import 'package:medi_crate/shared/widgets/feedback/app_empty_state.dart';
import 'package:medi_crate/shared/widgets/feedback/app_error_state.dart';
import 'package:medi_crate/shared/widgets/feedback/pulsing_vault_logo.dart';
import 'package:medi_crate/shared/widgets/forms/app_search_field.dart';

/// HospitalsListScreen presents profile-scoped healthcare facilities directory.
class HospitalsListScreen extends ConsumerStatefulWidget {
  const HospitalsListScreen({super.key});

  @override
  ConsumerState<HospitalsListScreen> createState() =>
      _HospitalsListScreenState();
}

class _HospitalsListScreenState extends ConsumerState<HospitalsListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(hospitalSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredHospitalsAsync = ref.watch(filteredHospitalsProvider);
    final allHospitalsAsync = ref.watch(hospitalsListProvider);
    final searchQuery = ref.watch(hospitalSearchQueryProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Hospitals & Clinics',
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
        onPressed: () => context.pushGuarded(AppRoutes.addHospital),
        icon: const Icon(AppIcons.hospital),
        label: const Text('Add Hospital'),
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
                  // Search Bar
                  AppSearchField(
                    controller: _searchController,
                    hintText: 'Search hospital, clinic, lab...',
                    onChanged: (val) {
                      ref.read(hospitalSearchQueryProvider.notifier).state =
                          val;
                    },
                    onClear: () {
                      _searchController.clear();
                      ref.read(hospitalSearchQueryProvider.notifier).state = '';
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Hospital Count Header & Sort Control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: allHospitalsAsync.when(
                          data: (allHosps) {
                            final count = allHosps.length;
                            final label = count == 1
                                ? '1 facility'
                                : '$count facilities';
                            return Text(
                              label,
                              style: AppTypography.subtitle.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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
                        currentSort: ref.watch(hospitalSortProvider),
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
                          ref.read(hospitalSortProvider.notifier).state = sort;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // List / Empty state
                  Expanded(
                    child: filteredHospitalsAsync.when(
                      loading: () => const Center(child: PulsingVaultLogo()),
                      error: (err, stack) => AppErrorState(
                        error: err,
                        title: 'Failed to load hospitals directory',
                        onRetry: () =>
                            ref.read(hospitalsListProvider.notifier).refresh(),
                      ),
                      data: (hospitals) {
                        if (hospitals.isEmpty) {
                          if (searchQuery.isNotEmpty) {
                            return _buildSearchEmptyState(context);
                          }
                          return _buildNoHospitalsEmptyState(context);
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: hospitals.length,
                          itemBuilder: (context, index) {
                            final hospital = hospitals[index];
                            return HospitalCard(
                              hospital: hospital,
                              onTap: () => context.pushGuarded(
                                AppRoutes.hospitalProfile(hospital.id),
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

  Widget _buildNoHospitalsEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.hospital,
      iconColor: context.semanticColors.hospitalAccent,
      iconContainerColor: context.semanticColors.hospitalAccentContainer,
      title: 'No hospitals added yet',
      message: 'Add hospitals, clinics, and laboratories to associate with your doctors and medical records.',
    );
  }

  Widget _buildSearchEmptyState(BuildContext context) {
    return AppEmptyState.filtered(
      icon: AppIcons.search,
      title: 'No matching hospitals found',
      message: 'Try searching for another name or location.',
      actionLabel: 'Clear search',
      actionIcon: null,
      onAction: () {
        _searchController.clear();
        ref.read(hospitalSearchQueryProvider.notifier).state = '';
      },
    );
  }
}
