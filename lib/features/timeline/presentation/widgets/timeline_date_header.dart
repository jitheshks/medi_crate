import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_typography.dart';

/// Section header displaying uppercase date for day-grouped timeline items.
class TimelineDateHeader extends StatelessWidget {
  final String dateHeader;

  const TimelineDateHeader({super.key, required this.dateHeader});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 18, bottom: 10),
      child: Text(
        dateHeader.toUpperCase(),
        style: AppTypography.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
