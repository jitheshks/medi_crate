import 'package:flutter/material.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Small semantic badge displaying report categories (LAB TEST, IMAGING, PRESCRIPTION, etc.).
class ReportTypeBadge extends StatelessWidget {
  final String category;

  const ReportTypeBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final cat = category.toUpperCase();
    final bg = categoryContainerColor(category, context);
    final fg = (cat == 'LAB TEST' || cat == 'LAB')
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : categoryColor(category, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        cat,
        style: AppTypography.labelMedium.copyWith(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// Helper returning leading category icon
  static IconData categoryIcon(String category) {
    final cat = category.toUpperCase();
    switch (cat) {
      case 'LAB TEST':
      case 'LAB':
        return Icons.water_drop_outlined;
      case 'PRESCRIPTION':
      case 'RX':
        return Icons.medication_outlined;
      case 'IMAGING':
      case 'RADIOLOGY':
      case 'X-RAY':
        return Icons.crop_free;
      case 'DISCHARGE':
        return Icons.assignment_turned_in_outlined;
      case 'CERTIFICATE':
        return Icons.verified_outlined;
      case 'VACCINATION':
      case 'VACCINE':
        return Icons.vaccines_outlined;
      case 'REFERRAL':
        return Icons.send_outlined;
      case 'OTHER':
      default:
        return Icons.description_outlined;
    }
  }

  /// Helper returning category container background color
  static Color categoryContainerColor(String category, BuildContext context) {
    final cat = category.toUpperCase();
    final semantics = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;

    switch (cat) {
      case 'LAB TEST':
      case 'LAB':
        return colorScheme.primaryContainer;
      case 'PRESCRIPTION':
      case 'RX':
        return semantics.medicineAccentContainer;
      case 'IMAGING':
      case 'RADIOLOGY':
      case 'X-RAY':
        return semantics.hospitalAccentContainer;
      case 'DISCHARGE':
      case 'CERTIFICATE':
        return semantics.departmentAccentContainer;
      case 'VACCINATION':
      case 'VACCINE':
        return semantics.successContainer;
      case 'REFERRAL':
        return semantics.vitalHeartRateContainer;
      case 'OTHER':
      default:
        return semantics.vitalWeightContainer;
    }
  }

  /// Helper returning leading category icon tint color
  static Color categoryColor(String category, BuildContext context) {
    final cat = category.toUpperCase();
    final semantics = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;

    switch (cat) {
      case 'LAB TEST':
      case 'LAB':
        return colorScheme.primary;
      case 'PRESCRIPTION':
      case 'RX':
        return semantics.medicineAccent;
      case 'IMAGING':
      case 'RADIOLOGY':
      case 'X-RAY':
        return semantics.hospitalAccent;
      case 'DISCHARGE':
      case 'CERTIFICATE':
        return semantics.departmentAccent;
      case 'VACCINATION':
      case 'VACCINE':
        return semantics.success;
      case 'REFERRAL':
        return semantics.vitalHeartRate;
      case 'OTHER':
      default:
        return semantics.vitalWeight;
    }
  }
}
