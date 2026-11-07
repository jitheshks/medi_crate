import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_currency.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/settings_providers.dart';
import '../routes/settings_sub_route.dart';
import '../widgets/settings_tile.dart';

/// SettingsScreen presents main settings categories, user profile summary, and sign out controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final user = authState.user;
    final userName = user?.name ?? 'My Account';
    final userEmail = user?.email ?? '';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'M';
    final colorScheme = Theme.of(context).colorScheme;

    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final syncSubtitle = pendingCountAsync.when(
      data: (count) => count > 0
          ? '$count pending change${count == 1 ? '' : 's'}'
          : 'Connectivity, queue count & manual sync',
      loading: () => pendingCountAsync.hasValue
          ? (pendingCountAsync.value! > 0
                ? '${pendingCountAsync.value!} pending change${pendingCountAsync.value! == 1 ? '' : 's'}'
                : 'Connectivity, queue count & manual sync')
          : 'Checking pending changes...',
      error: (_, _) => 'Connectivity, queue count & manual sync',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(
          color: colorScheme.onSurface,
          onPressed: () => context.popOrGo(AppRoutes.dashboard),
        ),
        title: Text(
          'Settings',
          style: AppTypography.h1.copyWith(color: colorScheme.onSurface),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHero(context, userName, userEmail, initial),
                  const SizedBox(height: 24),
                  _buildGroupHeader(context, 'ACCOUNT'),
                  const SettingsTile(
                    title: 'Account & Security',
                    subtitle: 'Password, email & account management',
                    icon: Icons.shield_outlined,
                    route: SettingsSubRoute.accountSecurity,
                  ),
                  const SettingsTile(
                    title: 'Notifications',
                    subtitle: 'Reminders, daily summary & alerts',
                    icon: Icons.notifications_none,
                    route: SettingsSubRoute.notifications,
                  ),
                  const SizedBox(height: 16),
                  _buildGroupHeader(context, 'APP PREFERENCES'),
                  const SettingsTile(
                    title: 'Appearance',
                    subtitle: 'Theme',
                    icon: Icons.palette_outlined,
                    route: SettingsSubRoute.appearance,
                  ),
                  SettingsTile(
                    title: 'Currency',
                    subtitle:
                        '${settings.appCurrency} (${AppCurrency.getSymbol(settings.appCurrency)})',
                    icon: Icons.currency_exchange,
                    route: SettingsSubRoute.currency,
                  ),
                  const SettingsTile(
                    title: 'Storage & Cache',
                    subtitle: 'Cache breakdown & clear data',
                    icon: Icons.storage_outlined,
                    route: SettingsSubRoute.storage,
                  ),
                  SettingsTile(
                    title: 'Data & Sync',
                    subtitle: syncSubtitle,
                    icon: Icons.sync,
                    route: SettingsSubRoute.dataSync,
                  ),
                  const SettingsTile(
                    title: 'Export Health Records',
                    subtitle: 'Generate client-side PDF summaries',
                    icon: Icons.picture_as_pdf_outlined,
                    route: SettingsSubRoute.exportRecords,
                  ),
                  const SizedBox(height: 16),
                  _buildGroupHeader(context, 'INFORMATION'),
                  const SettingsTile(
                    title: 'About MediCrate',
                    subtitle: 'Version details & legal terms',
                    icon: Icons.info_outline,
                    route: SettingsSubRoute.about,
                  ),
                  const SettingsTile(
                    title: 'Help & Support',
                    subtitle: 'FAQ & email support',
                    icon: Icons.help_outline,
                    route: SettingsSubRoute.helpSupport,
                  ),
                  const SizedBox(height: 16),
                  _buildSignOutTile(context, ref),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'MediCrate v1.0.0 (Build 1) · Encrypted Storage',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(
    BuildContext context,
    String name,
    String email,
    String initial,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colorScheme.primary,
            child: Text(
              initial,
              style: AppTypography.h1.copyWith(color: colorScheme.onPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.h2.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSignOutTile(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () async {
        await ref.read(authControllerProvider.notifier).signOut();
        if (context.mounted) context.go(AppRoutes.login);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.logout, color: colorScheme.error, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Sign Out',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
