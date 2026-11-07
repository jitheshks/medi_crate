import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';

/// DataSyncSettingsScreen displays connectivity status, sync queue metrics, force sync, and policy details.
class DataSyncSettingsScreen extends ConsumerWidget {
  const DataSyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<ManualSyncResult?>>(manualSyncControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        data: (result) {
          if (result != null) {
            context.showSnackBar(result.message);
          }
        },
        error: (err, _) {
          context.showSnackBar(
            'Synchronization could not be completed. It will retry automatically.',
          );
        },
      );
    });

    final manualSyncState = ref.watch(manualSyncControllerProvider);
    final isSyncing = manualSyncState.isLoading;

    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final isOnline = isOnlineAsync.value ?? true;
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final pendingQueueCount = pendingCountAsync.value ?? 0;
    // Reuses Home's own profile-scoped aggregate (same prefixes, same
    // profile_id matching, same clinicalCacheRevisionProvider reactivity) so
    // this count can never disagree with what Home displays -- without
    // pulling this screen into Home's background clinical-sync coordinator.
    final vaultCountAsync = ref.watch(localVaultRecordsCountProvider);

    final statusBg = isOnline
        ? semantic.successContainer
        : semantic.warningContainer;
    final statusBorder = isOnline ? semantic.success : semantic.warningBorder;
    final statusFg = isOnline ? semantic.success : semantic.onWarningContainer;

    return SettingsSubScaffold(
      title: 'Data & Sync',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusBorder),
            ),
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: statusFg,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnline
                            ? 'Online · Live Sync Ready'
                            : 'Offline Mode Active',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusFg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline
                            ? 'Local mutations sync automatically to server.'
                            : 'Changes are queued locally in Hive vault.',
                        style: AppTypography.caption.copyWith(color: statusFg),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsGroupCard(
            title: 'Queue & Metrics',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.queue, color: colorScheme.primary),
                title: Text(
                  'Pending Sync Items',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pendingQueueCount > 0
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    pendingCountAsync.when(
                      data: (c) => '$c pending',
                      loading: () => pendingCountAsync.hasValue
                          ? '${pendingCountAsync.value!} pending'
                          : 'Loading...',
                      error: (_, _) => 'Unavailable',
                    ),
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: pendingQueueCount > 0
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.dataset_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Total Local Records',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                trailing: Text(
                  vaultCountAsync.when(
                    data: (count) => '$count items',
                    loading: () => vaultCountAsync.hasValue
                        ? '${vaultCountAsync.value} items'
                        : 'Loading...',
                    error: (_, _) => 'Unavailable',
                  ),
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          PrimaryButton(
            text: isSyncing ? 'Synchronizing...' : 'Force Sync Now',
            isLoading: isSyncing,
            onPressed: isOnline && !isSyncing
                ? () => ref
                      .read(manualSyncControllerProvider.notifier)
                      .triggerForceSync()
                : null,
          ),
        ],
      ),
    );
  }
}
