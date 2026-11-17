import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../data/models/profile_model.dart';

/// ProfileDeleteHelper guards against permanent clinical data loss.
///
/// In MediCrate, cascading deletion of medical records is forbidden.
/// Permanent profile deletion remains disabled until profile archival
/// is formally supported.
class ProfileDeleteHelper {
  ProfileDeleteHelper._();

  static DateTime _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 500);

  static void confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProfileModel profile,
  ) {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) return;
    _lastOpenTime = now;

    if (profile.isPrimary) {
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
            'The primary account profile (${profile.fullName}) cannot be deleted.\n\nTo manage your primary account, visit Account Settings.',
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

    // Secondary family profile deletion disabled to protect clinical records
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Profile Protected',
              style: AppTypography.h2.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Permanent deletion for family profiles is currently disabled to prevent accidental loss of associated consultations, prescriptions, and medical records.\n\nProfile archival will be introduced in an upcoming release to preserve historical clinical data.',
          style: AppTypography.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}
