import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../shared/widgets/dialogs/deletion_impact_dialog.dart';
import '../../../data/models/appointment_model.dart';
import '../../providers/appointment_providers.dart';

class AppointmentDeletionHelper {
  static Future<void> confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    final impactItems = <DeletionImpactItem>[];
    if (appointment.doctorName.isNotEmpty &&
        appointment.doctorName != 'Dr. Practitioner') {
      impactItems.add(
        DeletionImpactItem(
          count: 1,
          label: 'Doctor (${appointment.doctorName})',
          description: 'will remain in your doctor list.',
          type: DeletionImpactType.recordKept,
        ),
      );
    }
    if (appointment.hospitalName != null &&
        appointment.hospitalName!.isNotEmpty) {
      impactItems.add(
        DeletionImpactItem(
          count: 1,
          label: 'Hospital (${appointment.hospitalName})',
          description: 'will remain in your hospital list.',
          type: DeletionImpactType.recordKept,
        ),
      );
    }

    final confirm = await DeletionImpactDialog.show(
      context,
      title: 'Delete Appointment?',
      recordName: appointment.title,
      recordType: 'Appointment',
      impactItems: impactItems,
      onConfirm: () {},
    );

    if (confirm == true) {
      await ref
          .read(appointmentsListProvider.notifier)
          .deleteAppointment(appointment.id);
      if (context.mounted) {
        context.popOrGo(AppRoutes.appointments);
      }
    }
  }
}
