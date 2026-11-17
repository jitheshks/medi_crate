import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';

/// AboutSettingsScreen presents app version, build info, and legal links.
class AboutSettingsScreen extends ConsumerWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final packageInfoAsync = ref.watch(appPackageInfoProvider);
    final versionText = packageInfoAsync.maybeWhen(
      data: (info) => 'Version ${info.version} (Build ${info.buildNumber})',
      orElse: () => 'Version 1.0.0 (Build 1)',
    );

    return SettingsSubScaffold(
      title: 'About MediCrate',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield,
                    color: colorScheme.onPrimary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'MediCrate',
                  style: AppTypography.h1.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  versionText,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SettingsGroupCard(
            title: 'Application Information',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Architecture',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                trailing: Text(
                  'Feature-First Offline-First',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Database Engine',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                trailing: Text(
                  'Hive NoSQL Encrypted Vault',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          SettingsGroupCard(
            title: 'Legal & Policies',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.article_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Terms of Service',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => context.pushGuarded(AppRoutes.termsPrivacy),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.privacy_tip_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Privacy Policy',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () => context.pushGuarded(AppRoutes.termsPrivacy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
