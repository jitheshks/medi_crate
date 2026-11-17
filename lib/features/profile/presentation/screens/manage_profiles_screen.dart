import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../providers/profile_providers.dart';
import '../widgets/family_profile_card.dart';
import '../widgets/family_profiles_empty_state.dart';
import '../widgets/profile_form_dialog.dart';

/// ManageProfilesScreen handles full CRUD operations for family health profiles.
class ManageProfilesScreen extends ConsumerWidget {
  const ManageProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesListProvider);
    final archivedProfilesAsync = ref.watch(archivedProfilesListProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            context.popOrGo(AppRoutes.dashboard);
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Managed Family Profiles',
              style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
            ),
            backgroundColor: colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
              onPressed: () => context.popOrGo(AppRoutes.dashboard),
            ),
            bottom: TabBar(
              tabs: const [
                Tab(
                  icon: Icon(Icons.people_outline),
                  text: 'Active Profiles',
                ),
                Tab(
                  icon: Icon(Icons.archive_outlined),
                  text: 'Archived Profiles',
                ),
              ],
              indicatorColor: colorScheme.primary,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: TabBarView(
                  children: [
                    // Tab 1: Active Profiles
                    RefreshIndicator(
                      onRefresh: () => ref
                          .read(profilesListProvider.notifier)
                          .refreshProfiles(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Family Profiles',
                                        style: AppTypography.h1.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Manage independent health records for family members under your account.',
                                        style: AppTypography.subtitle.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            profilesAsync.when(
                              data: (profiles) {
                                if (profiles.isEmpty) {
                                  return const FamilyProfilesEmptyState();
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: profiles.length,
                                  itemBuilder: (context, index) {
                                    final profile = profiles[index];
                                    final isActive =
                                        profile.profileId ==
                                        activeProfile?.profileId;

                                    return FamilyProfileCard(
                                      profile: profile,
                                      isActive: isActive,
                                    );
                                  },
                                );
                              },
                              loading: () => const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: PulsingVaultLogo()),
                              ),
                              error: (err, _) => AppErrorState(
                                error: err,
                                title: 'Unable to Load Profiles',
                                onRetry: () =>
                                    ref.invalidate(profilesListProvider),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tab 2: Archived Profiles
                    RefreshIndicator(
                      onRefresh: () => ref
                          .read(archivedProfilesListProvider.notifier)
                          .refresh(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Archived Profiles',
                              style: AppTypography.h1.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Historical records for inactive family members. Clinical data is preserved permanently and cannot be modified while archived.',
                              style: AppTypography.subtitle.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 20,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Archived profiles retain all clinical records, prescriptions, vitals, and reports permanently. They can be restored at any time to resume record management.',
                                      style: AppTypography.caption.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            archivedProfilesAsync.when(
                              data: (archived) {
                                if (archived.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 48,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.archive_outlined,
                                            size: 48,
                                            color: colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No Archived Profiles',
                                            style: AppTypography.h3.copyWith(
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'When you archive a family profile, it will appear here safely preserved.',
                                            style:
                                                AppTypography.caption.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: archived.length,
                                  itemBuilder: (context, index) {
                                    final profile = archived[index];
                                    return FamilyProfileCard(
                                      profile: profile,
                                      isActive: false,
                                      isArchivedView: true,
                                    );
                                  },
                                );
                              },
                              loading: () => const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(child: PulsingVaultLogo()),
                              ),
                              error: (err, _) => AppErrorState(
                                error: err,
                                title: 'Unable to Load Archived Profiles',
                                onRetry: () => ref
                                    .invalidate(archivedProfilesListProvider),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => ProfileFormDialog.show(context),
            backgroundColor: Theme.of(context).colorScheme.primary,
            icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
            label: Text(
              'Add Profile',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
