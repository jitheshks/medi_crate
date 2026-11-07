import 'package:flutter/material.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Small semantic badge displaying timeline event types (CONSULTATION, APPOINTMENT, etc.).
class TimelineEventBadge extends StatelessWidget {
  final String text;
  final Color? color;

  const TimelineEventBadge({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;
    final cat = text.toUpperCase();
    Color bg;
    Color fg;

    if (color != null) {
      bg = color!.withValues(alpha: 0.12);
      fg = color!;
    } else {
      switch (cat) {
        case 'CONSULTATION':
          bg = colorScheme.primaryContainer;
          fg = colorScheme.onPrimaryContainer;
          break;
        case 'APPOINTMENT':
          bg = colorScheme.primary.withValues(alpha: 0.12);
          fg = colorScheme.primary;
          break;
        case 'MEASUREMENT':
          bg = colorScheme.primary.withValues(alpha: 0.12);
          fg = colorScheme.primary;
          break;
        case 'MEDICINE':
          bg = semantic.medicineAccentContainer;
          fg = semantic.medicineAccent;
          break;
        case 'REPORT':
        case 'LAB TEST':
          bg = semantic.hospitalAccentContainer;
          fg = semantic.hospitalAccent;
          break;
        case 'EXPENSE':
          bg = semantic.departmentAccentContainer;
          fg = semantic.departmentAccent;
          break;
        default:
          bg = semantic.vitalWeightContainer;
          fg = semantic.vitalWeight;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        cat,
        style: AppTypography.labelMedium.copyWith(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
