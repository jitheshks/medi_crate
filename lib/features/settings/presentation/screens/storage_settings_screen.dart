import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';
import '../widgets/storage_breakdown_card.dart';

/// StorageSettingsScreen displays real storage breakdown and clear cache action.
class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsync = ref.watch(storageUsageProvider);

    return SettingsSubScaffold(
      title: 'Storage & Cache',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          storageAsync.when(
            data: (storageMap) => StorageBreakdownCard(storageMap: storageMap),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, st) => const StorageBreakdownCard(
              storageMap: {'hive': 0, 'cache': 0, 'total': 0},
            ),
          ),
          const SizedBox(height: 20),
          const SettingsGroupCard(
            title: 'Storage Actions',
            children: [_ClearCacheTile()],
          ),
        ],
      ),
    );
  }
}

class _ClearCacheTile extends ConsumerStatefulWidget {
  const _ClearCacheTile();

  @override
  ConsumerState<_ClearCacheTile> createState() => _ClearCacheTileState();
}

class _ClearCacheTileState extends ConsumerState<_ClearCacheTile> {
  bool _isClearingCache = false;

  Future<void> _handleClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Clear App Cache?'),
          content: const Text(
            'This will delete temporary cached images, PDF previews, and compiled assets. Your medical records will remain safely saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogTheme.colorScheme.error,
                foregroundColor: dialogTheme.colorScheme.onError,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear Cache'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isClearingCache = true);
    await ref.read(settingsRepositoryProvider).clearCache();

    if (!mounted) return;

    ref.invalidate(storageUsageProvider);
    setState(() => _isClearingCache = false);
    context.showSnackBar('Cache cleared successfully.');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.cleaning_services_outlined,
        color: colorScheme.primary,
      ),
      title: Text(
        'Clear Cache',
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        'Delete temporary image and preview cache files',
        style: AppTypography.caption.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _isClearingCache
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _isClearingCache ? null : _handleClearCache,
    );
  }
}
