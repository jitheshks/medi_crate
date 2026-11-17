import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_icons.dart';

class OcrFormFields extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController doctorController;
  final TextEditingController hospitalController;
  final TextEditingController notesController;

  const OcrFormFields({
    super.key,
    required this.titleController,
    required this.doctorController,
    required this.hospitalController,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Report Title',
            prefixIcon: Icon(AppIcons.fileText),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: doctorController,
          decoration: const InputDecoration(
            labelText: 'Doctor Name (Optional)',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: hospitalController,
          decoration: const InputDecoration(
            labelText: 'Hospital / Clinic (Optional)',
            prefixIcon: Icon(AppIcons.hospital),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: notesController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notes & Instructions',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }
}
