import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../data/models/profile_model.dart';

/// ProfileAvatar renders a styled avatar circle for a profile with relationship tinting.
class ProfileAvatar extends StatelessWidget {
  final ProfileModel profile;
  final double radius;

  const ProfileAvatar({super.key, required this.profile, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final color = _getRelationshipColor(profile.relationship, context);
    final textColor = Theme.of(context).colorScheme.onPrimary;

    final hasPhoto = profile.photo != null && profile.photo!.isNotEmpty;

    if (hasPhoto) {
      final photoStr = profile.photo!;
      if (photoStr.startsWith('http://') || photoStr.startsWith('https://')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: color,
          backgroundImage: NetworkImage(photoStr),
          onBackgroundImageError: (exception, stackTrace) {},
        );
      }

      final file = File(photoStr);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: color,
          backgroundImage: FileImage(file),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: profile.isPrimary
          ? Icon(AppIcons.userCheck, size: radius * 1.1, color: textColor)
          : Text(
              initial,
              style: AppTypography.h3.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.9,
              ),
            ),
    );
  }

  Color _getRelationshipColor(String relationship, BuildContext context) {
    final semantic = context.semanticColors;
    switch (relationship) {
      case ProfileRelationships.self:
        return Theme.of(context).colorScheme.primary;
      case ProfileRelationships.father:
        return semantic.departmentAccent;
      case ProfileRelationships.mother:
        return semantic.relationshipMother;
      case ProfileRelationships.spouse:
        return semantic.relationshipSpouse;
      case ProfileRelationships.son:
      case ProfileRelationships.daughter:
        return semantic.relationshipChild;
      case ProfileRelationships.grandfather:
      case ProfileRelationships.grandmother:
        return semantic.relationshipGrandparent;
      default:
        return semantic.hospitalAccent;
    }
  }
}
