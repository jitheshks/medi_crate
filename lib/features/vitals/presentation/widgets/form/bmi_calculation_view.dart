import 'package:flutter/material.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../profile/data/models/profile_model.dart';
import '../../../data/models/measurement_model.dart';
import '../vital_visuals_helper.dart';

class BmiCalculationView extends StatelessWidget {
  final ProfileModel? activeProfile;

  const BmiCalculationView({super.key, required this.activeProfile});

  @override
  Widget build(BuildContext context) {
    final height = activeProfile?.height;
    final weight = activeProfile?.weight;

    final hasHeight = height != null && height > 0;
    final hasWeight = weight != null && weight > 0;

    if (!hasHeight || !hasWeight) {
      String missingMessage;
      if (!hasHeight && !hasWeight) {
        missingMessage =
            'Add your height and weight to your profile to calculate BMI.';
      } else if (!hasHeight) {
        missingMessage = 'Height is required to calculate BMI. Update your profile with your height.';
      } else {
        missingMessage = 'Weight is required to calculate BMI. Update your profile with your weight.';
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              missingMessage,
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Update Profile',
              button: true,
              child: PrimaryButton(
                text: 'UPDATE PROFILE',
                icon: Icons.person_outline,
                onPressed: () => context.pushGuarded(AppRoutes.profile),
              ),
            ),
          ],
        ),
      );
    }

    final bmiValue = MeasurementModel.calculateBmiValue(height, weight)!;
    final bmiStatus = MeasurementModel.calculateStatus(
      type: 'bmi',
      numericValue: bmiValue,
      isAdult: activeProfile?.isAdult ?? true,
    );
    final isAdult = activeProfile?.isAdult ?? true;
    final statusVisuals = getStatusVisuals(context, bmiStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Height and Weight Summary Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'HEIGHT',
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${height % 1 == 0 ? height.toInt() : height} cm',
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                height: 36,
                width: 1,
                color: Theme.of(context).colorScheme.outline
                    .withValues(alpha: 0.5),
              ),
              Column(
                children: [
                  Text(
                    'WEIGHT',
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${weight % 1 == 0 ? weight.toInt() : weight} kg',
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Calculated BMI Result Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                'YOUR CALCULATED BMI',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                bmiValue.toStringAsFixed(1),
                style: AppTypography.display.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusVisuals.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bmiStatus,
                  style: AppTypography.caption.copyWith(
                    color: statusVisuals.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Explanation text
        Text(
          isAdult
              ? 'BMI is calculated from the height and weight saved in your profile.'
              : 'BMI is calculated from the height and weight saved in your profile. Adult reference categories are not applied.',
          style: AppTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
