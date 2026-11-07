import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../hospitals/data/models/hospital_model.dart';
import '../../../hospitals/presentation/providers/hospitals_providers.dart';
import '../../data/models/doctor_model.dart';
import '../providers/doctors_providers.dart';

class DoctorHospitalSelectionSection extends ConsumerWidget {
  final List<String> selectedHospitalIds;
  final DoctorModel? originalDoctor;
  final VoidCallback onOpenHospitalPicker;
  final ValueChanged<String> onRemoveHospital;

  const DoctorHospitalSelectionSection({
    super.key,
    required this.selectedHospitalIds,
    required this.originalDoctor,
    required this.onOpenHospitalPicker,
    required this.onRemoveHospital,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hospitalsAsync = ref.watch(hospitalsListProvider);
    final allHospitals = hospitalsAsync.value ?? [];

    final selectedHospitals = allHospitals
        .where((h) => selectedHospitalIds.contains(h.id))
        .toList();

    final consultationHospitals = <HospitalModel>[];
    if (originalDoctor != null) {
      final practicingAsync = ref.watch(
        doctorHospitalsProvider(originalDoctor!),
      );
      final practicing = practicingAsync.value ?? [];
      for (final item in practicing) {
        if (item.isFromConsultation &&
            !selectedHospitalIds.contains(item.hospital.id)) {
          consultationHospitals.add(item.hospital);
        }
      }
    }

    final hasAny =
        selectedHospitals.isNotEmpty || consultationHospitals.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'PRACTICES AT / HOSPITALS',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: onOpenHospitalPicker,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Manage Selection'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!hasAny)
          GestureDetector(
            onTap: onOpenHospitalPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.hospital,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+ Select Hospital / Clinic',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...selectedHospitals.map((hosp) {
                return Chip(
                  avatar: Icon(
                    AppIcons.hospital,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  label: Text(
                    '${hosp.name} (Direct)',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => onRemoveHospital(hosp.id),
                  backgroundColor: colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  side: BorderSide.none,
                );
              }),
              ...consultationHospitals.map((hosp) {
                return Chip(
                  avatar: Icon(
                    Icons.history_edu_outlined,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  label: Text(
                    '${hosp.name} (From consultation)',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: colorScheme.outline),
                );
              }),
              ActionChip(
                avatar: Icon(Icons.add, size: 14, color: colorScheme.primary),
                label: Text(
                  'Add Hospital',
                  style: TextStyle(fontSize: 13, color: colorScheme.primary),
                ),
                onPressed: onOpenHospitalPicker,
                backgroundColor: colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                side: BorderSide.none,
              ),
            ],
          ),
      ],
    );
  }
}
