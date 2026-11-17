import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/app_semantic_colors.dart';

/// OfflineBanner renders the persistent amber offline warning banner.
class OfflineBanner extends StatelessWidget {
  final String message;

  const OfflineBanner({
    super.key,
    this.message =
        'Offline mode — changes will save locally and sync automatically',
  });

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final bgColor = semantic.warningContainer;
    final borderColor = semantic.warningBorder;
    final textColor = semantic.onWarningContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.wifiOff, size: 16, color: textColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
