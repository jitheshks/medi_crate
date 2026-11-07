import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';

/// UpcomingFollowUpSection renders scheduled medical follow-ups or an empty state.
class UpcomingFollowUpSection extends StatelessWidget {
  final String? title;
  final DateTime? date;
  final String? doctorName;

  const UpcomingFollowUpSection({
    super.key,
    this.title,
    this.date,
    this.doctorName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFollowUp = title != null && title!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Upcoming follow-up',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.pushGuarded(AppRoutes.followups),
              child: Text(
                'View all >',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!hasFollowUp)
          _buildEmptyState(context)
        else
          _buildFollowUpCard(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.calendar,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No upcoming follow-ups scheduled',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Consultation follow-ups and reviews will appear here.',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 180,
            height: 42,
            child: PrimaryButton(
              text: 'Book Consultation',
              onPressed: () => context.pushGuarded(AppRoutes.consultationAdd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = date != null
        ? DateFormat('d MMM yyyy').format(date!)
        : '';
    final doctor = (doctorName != null && doctorName!.trim().isNotEmpty)
        ? doctorName!.trim()
        : 'Doctor';
    final followUpSubtitle = formattedDate.isNotEmpty
        ? 'Follow-up on $formattedDate · $doctor'
        : doctor;

    return InkWell(
      onTap: () => context.pushGuarded(AppRoutes.followups),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title!,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              followUpSubtitle,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
