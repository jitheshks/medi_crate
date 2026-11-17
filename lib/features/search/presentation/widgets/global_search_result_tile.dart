import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../data/models/global_search_result.dart';

/// GlobalSearchResultTile renders an individual search result item with its domain badge,
/// icon, titles, and handles guarded route navigation upon tap.
class GlobalSearchResultTile extends StatelessWidget {
  final GlobalSearchResult item;

  const GlobalSearchResultTile({super.key, required this.item});

  Color _getItemColor(BuildContext context, SearchEntityType type) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case SearchEntityType.consultation:
      case SearchEntityType.doctor:
      case SearchEntityType.appointment:
        return colorScheme.primary;
      case SearchEntityType.hospital:
      case SearchEntityType.report:
        return semantic.hospitalAccent;
      case SearchEntityType.medicine:
        return semantic.medicineAccent;
      case SearchEntityType.vital:
        return semantic.vitalHeartRate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemColor = _getItemColor(context, item.type);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(item.icon, color: itemColor, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.badgeText,
              style: AppTypography.caption.copyWith(
                color: itemColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.supportingText != null &&
              item.supportingText!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.supportingText!,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: () {
        Navigator.of(context).pop();
        context.pushGuarded(item.targetRoute);
      },
    );
  }
}
