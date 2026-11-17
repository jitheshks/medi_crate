import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/exceptions/app_exception.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../shared/widgets/dialogs/deletion_impact_dialog.dart';
import '../../../../doctors/data/models/doctor_hospital_relation.dart';
import '../../../../profile/presentation/providers/profile_providers.dart';
import '../../../data/models/consultation_model.dart';
import '../../providers/consultation_providers.dart';

/// Helper to present dependency-protected deletion for a consultation record.
class ConsultationDeleteHandler {
  static Future<void> confirmDelete({
    required BuildContext context,
    required WidgetRef ref,
    required ConsultationModel consultation,
    required void Function(EntityDependencies deps) onScrollToDependency,
  }) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;
    final consultationRepo = ref.read(consultationRepositoryProvider);
    final deps = await consultationRepo.getConsultationDependencies(
      activeProfile.profileId,
      consultation.id,
    );

    if (!context.mounted) return;

    await DeletionImpactDialog.showDependencyAware(
      context,
      recordName: consultation.diagnosis.isNotEmpty
          ? 'Consultation (${consultation.diagnosis})'
          : 'Consultation',
      recordType: 'Consultation',
      dependencies: deps,
      onViewLinkedRecords: () {
        onScrollToDependency(deps);
      },
      onConfirm: () async {
        try {
          await ref
              .read(consultationsListNotifierProvider.notifier)
              .deleteConsultation(consultation.id);
          if (context.mounted) {
            context.showSuccessSnackBar('Consultation deleted successfully.');
            context.popOrGo(AppRoutes.consultations);
          }
        } on ResourceHasDependenciesException catch (e) {
          if (context.mounted) {
            DeletionImpactDialog.show409Conflict(
              context,
              recordType: 'Consultation',
              customMessage: e.message,
              onViewLinkedRecords: () {
                onScrollToDependency(deps);
              },
            );
          }
        } catch (_) {
          if (context.mounted) {
            context.showErrorSnackBar(
              "Couldn't delete consultation. Please try again.",
            );
          }
        }
      },
    );
  }
}
