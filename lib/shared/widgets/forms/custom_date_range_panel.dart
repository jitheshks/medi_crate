import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import 'date_range_field_tile.dart';

/// CustomDateRangePanel renders an inline or popover panel allowing the user
/// to select a Start date and End date, validating chronological bounds,
/// and applying the selected range.
class CustomDateRangePanel extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final void Function(DateTime start, DateTime end) onApply;
  final VoidCallback? onCancel;

  const CustomDateRangePanel({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.onApply,
    this.onCancel,
  });

  @override
  State<CustomDateRangePanel> createState() => _CustomDateRangePanelState();
}

class _CustomDateRangePanelState extends State<CustomDateRangePanel> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  bool get _isApplyEnabled {
    if (_startDate == null || _endDate == null) return false;
    return !_startDate!.isAfter(_endDate!);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? _endDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now.add(const Duration(days: 365)))
          ? now
          : initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If end date is before new start date, clear or adjust end date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endDate ?? _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now.add(const Duration(days: 365)))
          ? now
          : initial,
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CUSTOM DATE RANGE',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.onCancel != null)
                GestureDetector(
                  onTap: widget.onCancel,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Start Date Picker Field
              Expanded(
                child: DateRangeFieldTile(
                  label: 'Start date',
                  date: _startDate,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 12),
              // End Date Picker Field
              Expanded(
                child: DateRangeFieldTile(
                  label: 'End date',
                  date: _endDate,
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons Row (Cancel & Apply)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onCancel != null) ...[
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'Cancel',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton(
                onPressed: _isApplyEnabled
                    ? () => widget.onApply(_startDate!, _endDate!)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Apply',
                  style: AppTypography.button.copyWith(
                    color: _isApplyEnabled
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
