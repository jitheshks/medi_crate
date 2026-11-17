import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../../../hospitals/data/models/hospital_model.dart';
import 'hospital_picker_browse_view.dart';
import 'hospital_picker_create_view.dart';

enum _HospitalPickerMode { browse, addNew }

/// Modal bottom sheet for browsing existing hospitals/facilities and adding new ones
/// within the Consultation creation and editing workflow.
class HospitalPickerSheet extends StatefulWidget {
  final String? currentHospitalId;
  final String? currentHospitalName;
  final ValueChanged<HospitalModel> onSelected;

  const HospitalPickerSheet({
    super.key,
    this.currentHospitalId,
    this.currentHospitalName,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    String? currentHospitalId,
    String? currentHospitalName,
    required ValueChanged<HospitalModel> onSelected,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) {
        return HospitalPickerSheet(
          currentHospitalId: currentHospitalId,
          currentHospitalName: currentHospitalName,
          onSelected: onSelected,
        );
      },
    );
  }

  @override
  State<HospitalPickerSheet> createState() => _HospitalPickerSheetState();
}

class _HospitalPickerSheetState extends State<HospitalPickerSheet> {
  _HospitalPickerMode _mode = _HospitalPickerMode.browse;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: _mode == _HospitalPickerMode.browse
          ? 'Select Hospital'
          : 'Add New Hospital / Clinic',
      child: _mode == _HospitalPickerMode.browse
          ? HospitalPickerBrowseView(
              currentHospitalId: widget.currentHospitalId,
              currentHospitalName: widget.currentHospitalName,
              onHospitalSelected: widget.onSelected,
              onAddNewRequested: () {
                setState(() => _mode = _HospitalPickerMode.addNew);
              },
            )
          : HospitalPickerCreateView(
              onHospitalSelected: widget.onSelected,
              onBack: () {
                setState(() => _mode = _HospitalPickerMode.browse);
              },
            ),
    );
  }
}
