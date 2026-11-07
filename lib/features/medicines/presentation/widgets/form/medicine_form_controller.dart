import 'package:flutter/material.dart';
import '../../../data/models/medicine_model.dart';

class MedicineFormController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  String? selectedForm;
  String? selectedFrequency;
  DateTime startDate = DateTime.now();
  DateTime? endDate;
  bool reminder = true;
  List<TimeOfDay> reminderTimes = [const TimeOfDay(hour: 9, minute: 0)];
  String? linkedConsultationId;
  String? linkedConsultationTitle;

  String? endDateError;

  void onFrequencyChanged(String? freq) {
    selectedFrequency = freq;
    if (freq == 'Once daily') {
      reminderTimes = [const TimeOfDay(hour: 9, minute: 0)];
    } else if (freq == 'Twice daily') {
      reminderTimes = [
        const TimeOfDay(hour: 9, minute: 0),
        const TimeOfDay(hour: 21, minute: 0),
      ];
    } else if (freq == '3 times a day') {
      reminderTimes = [
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 14, minute: 0),
        const TimeOfDay(hour: 20, minute: 0),
      ];
    } else if (freq == '4 times a day') {
      reminderTimes = [
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 12, minute: 0),
        const TimeOfDay(hour: 16, minute: 0),
        const TimeOfDay(hour: 20, minute: 0),
      ];
    } else if (reminderTimes.isEmpty) {
      reminderTimes = [const TimeOfDay(hour: 9, minute: 0)];
    }
  }

  void populateFromModel(MedicineModel m) {
    nameController.text = m.medicineName;
    dosageController.text = m.dosage;
    notesController.text = m.notes ?? '';
    selectedForm = m.form;
    selectedFrequency = m.frequency;
    startDate = m.startDate;
    endDate = m.endDate;
    reminder = m.reminder;
    linkedConsultationId = m.linkedConsultationId;
    linkedConsultationTitle = m.linkedConsultationTitle;

    if (m.reminderTimes != null && m.reminderTimes!.isNotEmpty) {
      reminderTimes = m.reminderTimes!.map((timeStr) {
        final parts = timeStr.split(':');
        final h = int.tryParse(parts[0]) ?? 9;
        final min = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        return TimeOfDay(hour: h, minute: min);
      }).toList();
    } else {
      onFrequencyChanged(m.frequency);
    }
  }

  bool validateEndDate() {
    if (endDate != null) {
      final startMidnight = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endMidnight = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (endMidnight.isBefore(startMidnight)) {
        endDateError = 'End Date cannot be before Start Date';
        return false;
      }
    }
    endDateError = null;
    return true;
  }

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    notesController.dispose();
  }
}
