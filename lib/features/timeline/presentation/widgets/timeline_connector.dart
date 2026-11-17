import 'package:material_ui/material_ui.dart';

/// Renders the vertical connector rail line and timeline node icon box.
class TimelineConnector extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool showTopLine;
  final bool showBottomLine;

  const TimelineConnector({
    super.key,
    required this.icon,
    required this.color,
    this.showTopLine = true,
    this.showBottomLine = true,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor;

    return SizedBox(
      width: 44,
      child: Column(
        children: [
          // Top vertical connector line
          Expanded(
            flex: 1,
            child: Container(
              width: 2,
              color: showTopLine ? dividerColor : Colors.transparent,
            ),
          ),

          // Node Icon Box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),

          // Bottom vertical connector line
          Expanded(
            flex: 2,
            child: Container(
              width: 2,
              color: showBottomLine ? dividerColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
