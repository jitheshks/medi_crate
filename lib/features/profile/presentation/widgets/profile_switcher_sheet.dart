import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../providers/profile_providers.dart';
import 'profile_avatar.dart';
import 'profile_form_dialog.dart';

/// ProfileSwitcherSheet allows switching the globally active health profile.
class ProfileSwitcherSheet extends ConsumerWidget {
  const ProfileSwitcherSheet({super.key});

  static void show(BuildContext context) {
    AppBottomSheet.show<void>(
      context: context,
      builder: (context) => const ProfileSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesListProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return AppBottomSheet(
      title: 'Switch Health Profile',
      trailing: IconButton(
        icon: Icon(
          Icons.settings_outlined,
          size: 20,
          color: colorScheme.onSurface,
        ),
        tooltip: 'Manage Profiles',
        onPressed: () {
          context.pop();
          context.pushGuarded(AppRoutes.profiles);
        },
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select a profile to view and manage health records.',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          profilesAsync.when(
            data: (profiles) {
              if (profiles.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No profiles found.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: profiles.map((p) {
                  final isActive =
                      activeProfile != null &&
                      p.profileId == activeProfile.profileId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isActive
                          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isActive
                                ? colorScheme.primary
                                : colorScheme.outline,
                            width: isActive ? 1.5 : 1.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: ProfileAvatar(profile: p, radius: 20),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.fullName,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (p.isPrimary) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.star,
                                size: 16,
                                color: context.semanticColors.favoriteStar,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          p.displayRelationship,
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: isActive
                            ? Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                                size: 22,
                              )
                            : null,
                        onTap: () async {
                          await ref
                              .read(activeProfileProvider.notifier)
                              .selectProfile(p);
                          if (context.mounted) {
                            context.pop();
                            context.showSnackBar(
                              'Switched to ${p.fullName}',
                              duration: const Duration(seconds: 2),
                            );
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unable to load profiles. Please try again.',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: colorScheme.outline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.pop();
                    ProfileFormDialog.show(context);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.pop();
                    context.pushGuarded(AppRoutes.profiles);
                  },
                  icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                  label: const Text('Manage All'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
