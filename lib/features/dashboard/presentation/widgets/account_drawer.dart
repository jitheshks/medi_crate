import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'account_drawer_header.dart';
import 'account_drawer_tile.dart';

/// AccountDrawer is the Material Design 3 Account Side Sheet/Drawer for the Dashboard Shell.
/// It provides centralized access to user account details, profile management, app settings, security, and sign out.
class AccountDrawer extends ConsumerWidget {
  const AccountDrawer({super.key});

  static bool _isDrawerOpen = false;

  /// Opens the AccountDrawer using [Scaffold.openDrawer] if available,
  /// or presents a modal side sheet.
  static void show(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer) {
      if (!scaffold.isDrawerOpen) {
        scaffold.openDrawer();
      }
    } else {
      if (_isDrawerOpen) return;
      _isDrawerOpen = true;
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Account Drawer',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, anim1, anim2) => const Align(
          alignment: Alignment.centerLeft,
          child: AccountDrawer(),
        ),
        transitionBuilder: (context, anim1, anim2, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
                ),
            child: child,
          );
        },
      ).then((_) {
        _isDrawerOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    final user = authState.user;
    final userName = activeProfile?.fullName ?? user?.name ?? 'My Account';
    final relationship = activeProfile?.relationship ?? 'Self';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'M';

    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Account Drawer',
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Drawer(
          elevation: 2,
          backgroundColor: colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(AppRadius.card * 1.5),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                AccountDrawerHeader(
                  activeProfile: activeProfile,
                  userName: userName,
                  relationship: relationship,
                  initial: initial,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    children: [
                      AccountDrawerTile(
                        icon: Icons.person_outline,
                        title: 'Profile',
                        subtitle: 'Personal & medical profile details',
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              context.pushGuarded(AppRoutes.profile);
                            }
                          });
                        },
                      ),
                      AccountDrawerTile(
                        icon: Icons.people_alt_outlined,
                        title: 'Manage Family Profiles',
                        subtitle: 'Add, edit, or remove family members',
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              context.pushGuarded(AppRoutes.profiles);
                            }
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: colorScheme.outline, height: 1),
                      ),
                      AccountDrawerTile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'App preferences & notifications',
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              context.pushGuarded(AppRoutes.settings);
                            }
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: colorScheme.outline, height: 1),
                      ),
                      AccountDrawerTile(
                        icon: AppIcons.logOut,
                        title: 'Sign Out',
                        subtitle: 'Clear session & return to login',
                        textColor: colorScheme.error,
                        iconColor: colorScheme.error,
                        onTap: () async {
                          Navigator.of(context).pop();
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                  child: Text(
                    'MediVault v1.0.0 · End-to-End Encrypted',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 11,
                    ),
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
