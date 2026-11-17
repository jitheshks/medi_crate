import 'package:material_ui/material_ui.dart';

/// DetailNoteBox renders a styled note/text box with fallback copy for empty content.
class DetailNoteBox extends StatelessWidget {
  final String? notes;
  final String fallbackText;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  const DetailNoteBox({
    super.key,
    required this.notes,
    this.fallbackText = 'Not recorded.',
    this.padding = const EdgeInsets.all(14.0),
    this.borderRadius = 14.0,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBg = backgroundColor ?? colorScheme.surface;
    final effectiveBorder = borderColor ?? colorScheme.outline;

    final hasContent = notes != null && notes!.trim().isNotEmpty;
    final displayContent = hasContent ? notes!.trim() : fallbackText;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder, width: 1),
      ),
      child: Text(
        displayContent,
        style: TextStyle(
          fontSize: 13,
          color: hasContent
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          height: 1.55,
        ),
      ),
    );
  }
}
