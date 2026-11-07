import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../data/models/consent_record_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';
import '../widgets/toggle_setting_row.dart';

/// PrivacySettingsScreen handles analytics, crash reporting toggles, and consent history log.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsControllerProvider);
    final consentList = ref.watch(consentHistoryProvider);

    return SettingsSubScaffold(
      title: 'Privacy & Consent',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Your health records are stored locally and encrypted on your device. MediVault never sells or shares your personal medical data.',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsGroupCard(
            title: 'Telemetry & Analytics',
            children: [
              ToggleSettingRow(
                icon: Icons.analytics_outlined,
                title: 'Anonymous Analytics',
                subtitle:
                    'Send aggregated usage stats to help improve MediVault',
                value: settings.analyticsEnabled,
                onChanged: (val) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .updateSettings(settings.copyWith(analyticsEnabled: val));
                },
              ),
              const Divider(),
              ToggleSettingRow(
                icon: Icons.bug_report_outlined,
                title: 'Crash Reporting',
                subtitle: 'Automatically report crash logs to assist bug fixes',
                value: settings.crashReportingEnabled,
                onChanged: (val) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(crashReportingEnabled: val),
                      );
                },
              ),
            ],
          ),
          SettingsGroupCard(
            title: 'Consent History',
            children: consentList.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No consent history recorded.',
                        style: AppTypography.caption.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]
                : consentList.map((ConsentRecordModel item) {
                    final dateStr = DateFormat(
                      'MMM dd, yyyy · HH:mm',
                    ).format(item.timestamp);
                    final successBg = context.semanticColors.successContainer;
                    final successFg = context.semanticColors.success;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.title,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: successBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  item.status,
                                  style: AppTypography.caption.copyWith(
                                    color: successFg,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.details,
                            style: AppTypography.caption.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: AppTypography.caption.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
        ],
      ),
    );
  }
}
