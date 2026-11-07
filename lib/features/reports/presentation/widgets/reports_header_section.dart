import 'package:flutter/material.dart';

import '../../../../core/constants/app_typography.dart';

class ReportsHeaderSection extends StatelessWidget {
  final int filteredCount;
  final int totalCount;

  const ReportsHeaderSection({
    super.key,
    required this.filteredCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIAGNOSTICS & LABS',
          style: AppTypography.labelMedium.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medical Reports',
              style: AppTypography.h1.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$filteredCount reports shown · $totalCount total',
              style: AppTypography.subtitle.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
