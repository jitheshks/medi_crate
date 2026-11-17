import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import 'detail_status_pill.dart';

/// DetailExpenseCard renders a financial summary card with amount, description, and status pill.
class DetailExpenseCard extends StatelessWidget {
  final String amountText;
  final String category;
  final String status;
  final Color? statusColor;
  final Color? statusBackgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const DetailExpenseCard({
    super.key,
    required this.amountText,
    this.category = 'Consultation fee',
    this.status = 'PAID',
    this.statusColor,
    this.statusBackgroundColor,
    this.borderRadius = AppRadius.card,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveStatusColor = statusColor ?? context.semanticColors.success;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colorScheme.outline, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          DetailStatusPill(
            label: status,
            color: effectiveStatusColor,
            backgroundColor: statusBackgroundColor,
          ),
        ],
      ),
    );
  }
}
