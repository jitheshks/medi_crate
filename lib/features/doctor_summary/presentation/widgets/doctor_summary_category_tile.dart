import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../providers/doctor_summary_providers.dart';

/// DoctorSummaryCategoryTile renders an accordion row for a clinical summary category
/// with a tristate selection checkbox and expandable list of individual item checkboxes.
class DoctorSummaryCategoryTile extends StatefulWidget {
  final DoctorSummaryCategory category;
  final List<Map<String, dynamic>> items;
  final bool isLast;
  final bool isCategorySelected;
  final Set<String> deselectedIds;
  final String Function(Map<String, dynamic>) titleBuilder;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  final void Function(
    DoctorSummaryCategory category,
    bool? currentTristate,
    List<Map<String, dynamic>> items,
  )
  onToggleCategory;
  final void Function(
    String itemId,
    bool isSelected,
    DoctorSummaryCategory category,
  )
  onToggleItem;

  const DoctorSummaryCategoryTile({
    super.key,
    required this.category,
    required this.items,
    required this.isLast,
    required this.isCategorySelected,
    required this.deselectedIds,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onToggleCategory,
    required this.onToggleItem,
  });

  @override
  State<DoctorSummaryCategoryTile> createState() =>
      _DoctorSummaryCategoryTileState();
}

class _DoctorSummaryCategoryTileState extends State<DoctorSummaryCategoryTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final categoryItemIds = widget.items
        .map((i) => getSummaryItemId(i, widget.category))
        .toSet();
    final deselectedCount = categoryItemIds
        .intersection(widget.deselectedIds)
        .length;

    bool? tristateVal;
    if (!widget.isCategorySelected) {
      tristateVal = false;
    } else if (widget.items.isEmpty) {
      tristateVal = true;
    } else if (deselectedCount == 0) {
      tristateVal = true;
    } else if (deselectedCount == widget.items.length) {
      tristateVal = false;
    } else {
      tristateVal = null; // Tristate dash for partial selection
    }

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Checkbox(
                  tristate: true,
                  value: tristateVal,
                  onChanged: (val) {
                    widget.onToggleCategory(
                      widget.category,
                      tristateVal,
                      widget.items,
                    );
                  },
                ),
                Icon(
                  widget.category.icon,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${widget.category.label} (${widget.items.length})',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No ${widget.category.label.toLowerCase()} available for current filter.',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...widget.items.map((item) {
              final id = getSummaryItemId(item, widget.category);
              final isItemSelected =
                  widget.isCategorySelected &&
                  !widget.deselectedIds.contains(id);

              return CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(
                  left: 48,
                  right: AppSpacing.md,
                ),
                title: Text(
                  widget.titleBuilder(item),
                  style: AppTypography.caption.copyWith(
                    fontWeight: isItemSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isItemSelected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                subtitle: Text(
                  widget.subtitleBuilder(item),
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                value: isItemSelected,
                onChanged: (val) {
                  widget.onToggleItem(id, val ?? false, widget.category);
                },
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
          const SizedBox(height: 4),
        ],
        if (!widget.isLast) const Divider(height: 1),
      ],
    );
  }
}
