import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';
import '../widgets/toggle_setting_row.dart';

/// NotificationSettingsScreen manages notification categories, time pickers, and sound/vibration options.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final masterEnabled = settings.masterNotificationsEnabled;

    return SettingsSubScaffold(
      title: 'Notifications',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsGroupCard(
            title: 'Master Control',
            children: [
              ToggleSettingRow(
                icon: Icons.notifications_active_outlined,
                title: 'Allow Notifications',
                subtitle: 'Master toggle to enable or disable all app alerts',
                value: masterEnabled,
                onChanged: (val) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(masterNotificationsEnabled: val),
                      );
                },
              ),
            ],
          ),
          SettingsGroupCard(
            title: 'Health Reminders',
            children: [
              ToggleSettingRow(
                icon: Icons.medication_outlined,
                title: 'Medicine Reminders',
                subtitle: 'Alerts for scheduled medication dosages',
                value: masterEnabled && settings.medicineRemindersEnabled,
                enabled: masterEnabled,
                onChanged: (val) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(medicineRemindersEnabled: val),
                      );
                },
              ),
              const Divider(),
              ToggleSettingRow(
                icon: Icons.event_available_outlined,
                title: 'Appointment Reminders',
                subtitle: 'Notifications for upcoming doctor appointments',
                value: masterEnabled && settings.appointmentRemindersEnabled,
                enabled: masterEnabled,
                onChanged: (val) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(appointmentRemindersEnabled: val),
                      );
                },
              ),
              const Divider(),
              ToggleSettingRow(
                icon: Icons.assignment_return_outlined,
                title: 'Follow-up Reminders',
                subtitle: 'Reminders for consultation follow-up dates',
                value: masterEnabled && settings.followUpRemindersEnabled,
                enabled: masterEnabled,
                onChanged: (val) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(followUpRemindersEnabled: val),
                      );
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: masterEnabled,
                leading: Icon(
                  Icons.access_time,
                  color: masterEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  'Daily Summary Time',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: masterEnabled
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                subtitle: Text(
                  'Time to receive daily health digest',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  settings.dailySummaryTime,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: masterEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: masterEnabled
                    ? () async {
                        final parts = settings.dailySummaryTime.split(':');
                        final initialTime = TimeOfDay(
                          hour: int.tryParse(parts[0]) ?? 20,
                          minute:
                              int.tryParse(parts.length > 1 ? parts[1] : '0') ??
                              0,
                        );
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initialTime,
                        );
                        if (picked != null) {
                          final formatted =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          ref
                              .read(settingsControllerProvider.notifier)
                              .updateSettings(
                                settings.copyWith(dailySummaryTime: formatted),
                              );
                        }
                      }
                    : null,
              ),
            ],
          ),
          SettingsGroupCard(
            title: 'Sound & Haptics',
            children: [
              ToggleSettingRow(
                icon: Icons.volume_up_outlined,
                title: 'Notification Sound',
                subtitle: 'Play sound effect for notifications',
                value: masterEnabled && settings.notificationSoundEnabled,
                enabled: masterEnabled,
                onChanged: (val) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(notificationSoundEnabled: val),
                      );
                },
              ),
              const Divider(),
              ToggleSettingRow(
                icon: Icons.vibration,
                title: 'Vibration',
                subtitle: 'Vibrate device upon receiving alerts',
                value: masterEnabled && settings.notificationVibrationEnabled,
                enabled: masterEnabled,
                onChanged: (val) {
                  ref
                      .read(settingsControllerProvider.notifier)
                      .updateSettings(
                        settings.copyWith(notificationVibrationEnabled: val),
                      );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
