import 'package:flutter/material.dart';
import 'detail_section_header.dart';

/// DetailSection renders a section header followed by its content child.
class DetailSection extends StatelessWidget {
  final String title;
  final Widget child;
  final double topPadding;
  final double bottomPadding;
  final bool isHighlighted;

  const DetailSection({
    super.key,
    required this.title,
    required this.child,
    this.topPadding = 20.0,
    this.bottomPadding = 8.0,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: isHighlighted
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? colorScheme.primary.withValues(alpha: 0.40)
              : Colors.transparent,
          width: isHighlighted ? 1.5 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailSectionHeader(
            title: title,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
          ),
          child,
        ],
      ),
    );
  }
}
