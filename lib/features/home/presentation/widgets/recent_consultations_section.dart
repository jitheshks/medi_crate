import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';

/// RecentConsultationsSection renders the most recent clinical consultation entry.
class RecentConsultationsSection extends StatelessWidget {
  final String? consultationId;
  final String? diagnosis;
  final DateTime? date;
  final String? doctorName;

  const RecentConsultationsSection({
    super.key,
    this.consultationId,
    this.diagnosis,
    this.date,
    this.doctorName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasConsultation =
        consultationId != null &&
        consultationId!.isNotEmpty &&
        diagnosis != null &&
        diagnosis!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Recent Consultations',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.pushGuarded(AppRoutes.consultations),
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
        if (!hasConsultation)
          _buildEmptyState(context)
        else
          _buildConsultationCard(context),
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
            AppIcons.stethoscope,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No consultations recorded yet',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Record doctor visits, diagnoses, and medical prescriptions.',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 200,
            height: 42,
            child: PrimaryButton(
              text: 'Create Consultation',
              onPressed: () => context.pushGuarded(AppRoutes.consultationAdd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = date != null
        ? DateFormat('d MMM yyyy').format(date!)
        : '';
    final doctor = (doctorName != null && doctorName!.isNotEmpty)
        ? doctorName!
        : 'Doctor';

    return InkWell(
      onTap: () {
        if (consultationId != null && consultationId!.isNotEmpty) {
          context.pushGuarded(AppRoutes.consultationDetail(consultationId!));
        } else {
          context.pushGuarded(AppRoutes.consultations);
        }
      },
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
              diagnosis!,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formattedDate.isNotEmpty ? '$doctor · $formattedDate' : doctor,
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
