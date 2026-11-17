import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../../../doctors/data/models/doctor_model.dart';
import 'doctor_picker_browse_view.dart';
import 'doctor_picker_create_view.dart';

enum _DoctorPickerMode { browse, addNew }

/// Modal bottom sheet for browsing existing doctors and adding new doctors
/// within the Consultation creation and editing workflow.
class DoctorPickerSheet extends StatefulWidget {
  final String? currentDoctorId;
  final String? currentDoctorName;
  final ValueChanged<DoctorModel> onSelected;

  const DoctorPickerSheet({
    super.key,
    this.currentDoctorId,
    this.currentDoctorName,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    String? currentDoctorId,
    String? currentDoctorName,
    required ValueChanged<DoctorModel> onSelected,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) {
        return DoctorPickerSheet(
          currentDoctorId: currentDoctorId,
          currentDoctorName: currentDoctorName,
          onSelected: onSelected,
        );
      },
    );
  }

  @override
  State<DoctorPickerSheet> createState() => _DoctorPickerSheetState();
}

class _DoctorPickerSheetState extends State<DoctorPickerSheet> {
  _DoctorPickerMode _mode = _DoctorPickerMode.browse;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: _mode == _DoctorPickerMode.browse
          ? 'Select Doctor'
          : 'Add New Doctor',
      child: _mode == _DoctorPickerMode.browse
          ? DoctorPickerBrowseView(
              currentDoctorId: widget.currentDoctorId,
              currentDoctorName: widget.currentDoctorName,
              onDoctorSelected: widget.onSelected,
              onAddNewRequested: () {
                setState(() => _mode = _DoctorPickerMode.addNew);
              },
            )
          : DoctorPickerCreateView(
              onDoctorSelected: widget.onSelected,
              onBack: () {
                setState(() => _mode = _DoctorPickerMode.browse);
              },
            ),
    );
  }
}
