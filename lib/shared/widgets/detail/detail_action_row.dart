import 'package:material_ui/material_ui.dart';

/// DetailActionRow renders standardized bottom action buttons (Edit, Delete, and optional additional actions).
class DetailActionRow extends StatefulWidget {
  final VoidCallback? onEdit;
  final String editLabel;
  final IconData editIcon;
  final VoidCallback? onDelete;
  final String deleteLabel;
  final IconData deleteIcon;
  final List<Widget>? additionalActions;
  final double height;
  final EdgeInsetsGeometry padding;
  final double gap;

  const DetailActionRow({
    super.key,
    this.onEdit,
    this.editLabel = 'EDIT',
    this.editIcon = Icons.edit_outlined,
    this.onDelete,
    this.deleteLabel = 'DELETE',
    this.deleteIcon = Icons.delete_outline,
    this.additionalActions,
    this.height = 46.0,
    this.padding = const EdgeInsets.only(top: 24.0, bottom: 40.0),
    this.gap = 10.0,
  });

  @override
  State<DetailActionRow> createState() => _DetailActionRowState();
}

class _DetailActionRowState extends State<DetailActionRow> {
  DateTime _lastActionTime = DateTime.fromMillisecondsSinceEpoch(0);

  bool _canExecuteAction() {
    final now = DateTime.now();
    if (now.difference(_lastActionTime) < const Duration(milliseconds: 500)) {
      return false;
    }
    _lastActionTime = now;
    return true;
  }

  void _handleEdit() {
    if (_canExecuteAction()) {
      widget.onEdit?.call();
    }
  }

  void _handleDelete() {
    if (_canExecuteAction()) {
      widget.onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttons = <Widget>[];

    if (widget.additionalActions != null) {
      buttons.addAll(widget.additionalActions!);
    }

    if (widget.onEdit != null) {
      buttons.add(
        Expanded(
          child: SizedBox(
            height: widget.height,
            child: OutlinedButton.icon(
              onPressed: _handleEdit,
              icon: Icon(
                widget.editIcon,
                size: 14,
                color: colorScheme.onSurface,
              ),
              label: Text(
                widget.editLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: colorScheme.surface,
                side: BorderSide(color: colorScheme.outline, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.onDelete != null) {
      buttons.add(
        Expanded(
          child: SizedBox(
            height: widget.height,
            child: Material(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _handleDelete,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.error, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.deleteIcon,
                        size: 14,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.deleteLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: widget.padding,
      child: Row(
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) SizedBox(width: widget.gap),
            buttons[i],
          ],
        ],
      ),
    );
  }
}
