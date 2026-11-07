import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/dialogs/deletion_impact_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/profile_model.dart';
import '../providers/profile_providers.dart';

class ProfileDeleteHelper {
  static DateTime _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 500);

  static void confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
  ) {
    if (profile.isPrimary) {
      final now = DateTime.now();
      if (now.difference(_lastOpenTime) < _cooldown) return;
      _lastOpenTime = now;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Primary Profile',
                style: AppTypography.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            'The primary account profile (${profile.fullName}) cannot be deleted.\n\nTo delete your primary profile and account, use Delete Account in Settings.',
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final hive = ref.read(hiveServiceProvider);
    final box = hive.userBox;
    int consultationCount = 0;
    int reportCount = 0;
    int medicineCount = 0;
    int appointmentCount = 0;
    int doctorCount = 0;
    int hospitalCount = 0;
    int measurementCount = 0;

    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map && val['profile_id'] == profile.profileId) {
        final kStr = key.toString();
        if (kStr.startsWith('con_')) {
          consultationCount++;
        } else if (kStr.startsWith('report_')) {
          reportCount++;
        } else if (kStr.startsWith('medicine_')) {
          medicineCount++;
        } else if (kStr.startsWith('appointment_')) {
          appointmentCount++;
        } else if (kStr.startsWith('doctor_')) {
          doctorCount++;
        } else if (kStr.startsWith('hospital_')) {
          hospitalCount++;
        } else if (kStr.startsWith('measurement_')) {
          measurementCount++;
        }
      }
    }

    final impactItems = <DeletionImpactItem>[];
    if (consultationCount > 0) {
      impactItems.add(
        DeletionImpactItem(
          count: consultationCount,
          label: consultationCount == 1 ? 'Consultation' : 'Consultations',
          description: 'will be permanently deleted.',
          type: DeletionImpactType.recordDeleted,
        ),
      );
    }
    if (reportCount > 0) {
      impactItems.add(
        DeletionImpactItem(
          count: reportCount,
          label: reportCount == 1 ? 'Report' : 'Reports',
          description: 'will be permanently deleted.',
          type: DeletionImpactType.recordDeleted,
        ),
      );
    }
    if (medicineCount > 0) {
      impactItems.add(
        DeletionImpactItem(
          count: medicineCount,
          label: medicineCount == 1 ? 'Medicine' : 'Medicines',
          description: 'will be permanently deleted.',
          type: DeletionImpactType.recordDeleted,
        ),
      );
    }
    if (appointmentCount > 0) {
      impactItems.add(
        DeletionImpactItem(
          count: appointmentCount,
          label: appointmentCount == 1 ? 'Appointment' : 'Appointments',
          description: 'will be permanently deleted.',
          type: DeletionImpactType.recordDeleted,
        ),
      );
    }
    if (measurementCount > 0) {
      impactItems.add(
        DeletionImpactItem(
          count: measurementCount,
          label: measurementCount == 1 ? 'Measurement' : 'Measurements',
          description: 'will be permanently deleted.',
          type: DeletionImpactType.recordDeleted,
        ),
      );
    }
    if (doctorCount > 0) {
      impactItems.add(
        DeletionImpactItem(
          count: doctorCount,
          label: doctorCount == 1 ? 'Doctor' : 'Doctors',
          description: 'will be permanently deleted from this profile.',
          type: DeletionImpactType.recordDeleted,
        ),
      );
    }
    if (hospitalCount > 0) {
      impactItems.add(
        DeletionImpactItem(
          count: hospitalCount,
          label: hospitalCount == 1 ? 'Hospital' : 'Hospitals',
          description: 'will be permanently deleted from this profile.',
          type: DeletionImpactType.recordDeleted,
        ),
      );
    }

    DeletionImpactDialog.show(
      context,
      title: 'Delete Family Profile?',
      recordName: "${profile.fullName}'s Profile",
      recordType: 'Profile',
      impactItems: impactItems,
      customWarning: 'All health records belonging to this profile will be permanently deleted.',
      onConfirm: () async {
        await ref
            .read(profilesListProvider.notifier)
            .deleteProfile(profile.profileId);
        if (context.mounted) {
          context.showSnackBar('${profile.fullName}\'s profile deleted.');
        }
      },
    );
  }
}
