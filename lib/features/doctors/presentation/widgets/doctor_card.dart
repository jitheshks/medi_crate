import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_crate/core/constants/app_icons.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:medi_crate/features/doctors/presentation/providers/doctors_providers.dart';
import 'package:medi_crate/shared/widgets/cards/entity_tile_card.dart';

/// DoctorCard displays compact doctor summary info in a list tile.
/// Strictly NO favorite / heart icons per product requirements.
class DoctorCard extends ConsumerWidget {
  final DoctorModel doctor;
  final VoidCallback onTap;

  const DoctorCard({super.key, required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleParts = <String>[doctor.specialty];
    final String? hospitalText;
    if (doctor.hospitalIds.isEmpty) {
      hospitalText = doctor.hospitalName;
    } else {
      final hospitalsAsync = ref.watch(doctorHospitalsProvider(doctor));
      hospitalText =
          (hospitalsAsync.hasValue && hospitalsAsync.value!.isNotEmpty)
          ? hospitalsAsync.value!.map((h) => h.name).join(', ')
          : doctor.hospitalName;
    }

    if (hospitalText != null && hospitalText.isNotEmpty) {
      subtitleParts.add(hospitalText);
    }
    final subtitle = subtitleParts.join(' · ');

    final colorScheme = Theme.of(context).colorScheme;
    return EntityTileCard(
      title: doctor.name,
      subtitle: subtitle,
      phone: doctor.phone,
      icon: AppIcons.stethoscope,
      iconColor: colorScheme.primary,
      iconBackgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.6),
      onTap: onTap,
    );
  }
}
