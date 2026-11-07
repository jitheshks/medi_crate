import 'package:flutter/material.dart';
import '../../../../../core/constants/app_typography.dart';

class VitalAdultReferenceNotice extends StatelessWidget {
  final String title;

  const VitalAdultReferenceNotice({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title reference ranges are intended for adult profiles (18+). Reading will be saved without adult status classification.',
              style: AppTypography.caption.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
