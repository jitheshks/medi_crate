import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../doctors/data/models/doctor_model.dart';

class LinkedDoctorCard extends StatelessWidget {
  final AsyncValue<List<DoctorModel>> doctorsAsync;
  final String? doctorName;
  final VoidCallback onOpenDoctorPicker;
  final VoidCallback onClearDoctor;

  const LinkedDoctorCard({
    super.key,
    required this.doctorsAsync,
    required this.doctorName,
    required this.onOpenDoctorPicker,
    required this.onClearDoctor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DOCTOR',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        doctorsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (err, stack) => const SizedBox.shrink(),
          data: (doctors) {
            final hasDoctor =
                doctorName != null && doctorName!.trim().isNotEmpty;
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                side: BorderSide(color: colorScheme.outline),
              ),
              color: colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.input),
                onTap: onOpenDoctorPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.stethoscope,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doctor',
                              style: AppTypography.caption.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              hasDoctor ? doctorName! : 'Not linked',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: hasDoctor
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasDoctor)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: onClearDoctor,
                        )
                      else
                        Icon(
                          Icons.arrow_drop_down,
                          color: colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
