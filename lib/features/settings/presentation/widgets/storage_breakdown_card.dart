import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';

/// StorageBreakdownCard displays disk storage usage and progress indicator.
class StorageBreakdownCard extends StatelessWidget {
  final Map<String, int> storageMap;

  const StorageBreakdownCard({super.key, required this.storageMap});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final hiveBytes = storageMap['hive'] ?? 0;
    final cacheBytes = storageMap['cache'] ?? 0;
    final totalBytes = storageMap['total'] ?? (hiveBytes + cacheBytes);

    final hiveRatio = totalBytes > 0
        ? (hiveBytes / totalBytes).clamp(0.0, 1.0)
        : 0.4;

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Storage Used',
                style: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                _formatBytes(totalBytes),
                style: AppTypography.h2.copyWith(color: colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: hiveRatio,
              minHeight: 10,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegend(
                context,
                'Hive Database',
                _formatBytes(hiveBytes),
                colorScheme.primary,
              ),
              _buildLegend(
                context,
                'App Cache',
                _formatBytes(cacheBytes),
                colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: AppTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
