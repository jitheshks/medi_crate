import 'package:flutter/material.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../profile/data/models/profile_model.dart';

class ConsultationProfileBanner extends StatelessWidget {
  final ProfileModel? profile;

  const ConsultationProfileBanner({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Recording for profile: ${profile!.fullName} (${profile!.relationship})',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
