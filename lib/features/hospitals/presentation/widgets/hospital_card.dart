import 'package:flutter/material.dart';
import 'package:medi_crate/core/constants/app_icons.dart';
import 'package:medi_crate/core/theme/app_semantic_colors.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';
import 'package:medi_crate/shared/widgets/cards/entity_tile_card.dart';

/// HospitalCard displays summary info for a healthcare facility in a list tile.
class HospitalCard extends StatelessWidget {
  final HospitalModel hospital;
  final VoidCallback onTap;

  const HospitalCard({super.key, required this.hospital, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (hospital.type != null && hospital.type!.isNotEmpty) {
      subtitleParts.add(hospital.type!);
    }
    if (hospital.address != null && hospital.address!.isNotEmpty) {
      subtitleParts.add(hospital.address!);
    }
    final subtitle = subtitleParts.isEmpty
        ? 'Facility'
        : subtitleParts.join(' · ');

    final semanticColors = context.semanticColors;

    return EntityTileCard(
      title: hospital.name,
      subtitle: subtitle,
      phone: hospital.phone,
      icon: AppIcons.hospital,
      iconColor: semanticColors.hospitalAccent,
      iconBackgroundColor: semanticColors.hospitalAccentContainer,
      onTap: onTap,
    );
  }
}
