import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_typography.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';

/// AppearanceSettingsScreen handles theme mode selection (System, Light, Dark).
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return SettingsSubScaffold(
      title: 'Appearance',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsGroupCard(
            title: 'Theme',
            children: [
              _buildThemeTile(
                context,
                ref,
                title: 'System',
                subtitle: 'Match operating system dark/light settings',
                value: 'system',
                selectedValue: settings.themeMode,
              ),
              const Divider(),
              _buildThemeTile(
                context,
                ref,
                title: 'Light',
                subtitle: 'Calm off-white MediVault standard theme',
                value: 'light',
                selectedValue: settings.themeMode,
              ),
              const Divider(),
              _buildThemeTile(
                context,
                ref,
                title: 'Dark',
                subtitle: 'Sleek dark mode theme for low light environments',
                value: 'dark',
                selectedValue: settings.themeMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required String value,
    required String selectedValue,
  }) {
    final isSelected = value == selectedValue;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () {
        ref.read(settingsControllerProvider.notifier).setThemeMode(value);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? primaryColor : unselectedColor,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
