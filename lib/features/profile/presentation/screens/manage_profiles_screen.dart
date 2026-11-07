import 'package:flutter/material.dart';
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
    final activeProfile = ref.watch(activeProfileProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
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
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                profile.profileId == activeProfile?.profileId;

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
                        onRetry: () => ref.invalidate(profilesListProvider),
                      ),
                    ),
                  ],
                ),
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
    );
  }
}
