import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../hospitals/data/models/hospital_model.dart';

class LinkedHospitalCard extends StatelessWidget {
  final AsyncValue<List<HospitalModel>> hospitalsAsync;
  final String? hospitalName;
  final VoidCallback onOpenHospitalPicker;
  final VoidCallback onClearHospital;

  const LinkedHospitalCard({
    super.key,
    required this.hospitalsAsync,
    required this.hospitalName,
    required this.onOpenHospitalPicker,
    required this.onClearHospital,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HOSPITAL / CLINIC',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        hospitalsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (err, stack) => const SizedBox.shrink(),
          data: (hospitals) {
            final hasHospital =
                hospitalName != null && hospitalName!.trim().isNotEmpty;
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                side: BorderSide(color: colorScheme.outline),
              ),
              color: colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.input),
                onTap: onOpenHospitalPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.hospital,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hospital / Clinic',
                              style: AppTypography.caption.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              hasHospital ? hospitalName! : 'Not linked',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: hasHospital
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasHospital)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: onClearHospital,
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
