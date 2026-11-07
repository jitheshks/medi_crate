import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// CareDirectorySection renders side-by-side Doctor & Hospital count cards.
class CareDirectorySection extends StatelessWidget {
  final int doctorCount;
  final int hospitalCount;

  const CareDirectorySection({
    super.key,
    required this.doctorCount,
    required this.hospitalCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Care directory',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildCareCard(
                context,
                title: 'Doctors',
                count: '$doctorCount saved',
                icon: AppIcons.stethoscope,
                iconBgColor: colorScheme.primaryContainer.withValues(
                  alpha: 0.6,
                ),
                iconColor: colorScheme.primary,
                onTap: () => context.pushGuarded(AppRoutes.doctors),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCareCard(
                context,
                title: 'Hospitals',
                count: '$hospitalCount saved',
                icon: AppIcons.hospital,
                iconBgColor: semanticColors.hospitalAccentContainer,
                iconColor: semanticColors.hospitalAccent,
                onTap: () => context.pushGuarded(AppRoutes.hospitals),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCareCard(
    BuildContext context, {
    required String title,
    required String count,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
