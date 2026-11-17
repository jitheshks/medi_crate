import 'package:material_ui/material_ui.dart';

import '../../../data/models/appointment_model.dart';

class AppointmentFormController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController costController = TextEditingController();

  String? selectedDoctorName;
  String? selectedDoctorId;
  String? selectedDoctorSpecialty;
  String? selectedHospitalName;
  String? selectedHospitalId;
  String? selectedDepartment;
  String? selectedDepartmentId;
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool reminderEnabled = true;
  String? selectedCurrency;

  List<String> titleSuggestions = [];

  void populateFromAppointment(AppointmentModel model) {
    titleController.text = model.title;
    selectedDoctorName = model.doctorName;
    selectedDoctorId = model.doctorId;
    selectedDoctorSpecialty = model.doctorSpecialty;
    selectedHospitalName = model.hospitalName;
    selectedHospitalId = model.hospitalId;
    selectedDepartment = model.department;
    selectedDepartmentId = model.departmentId;
    selectedDate = model.date;
    selectedTime = TimeOfDay.fromDateTime(model.date);
    reminderEnabled = model.reminderEnabled;
    notesController.text = model.notes ?? '';
    costController.text = model.cost != null
        ? model.cost!.toStringAsFixed(0)
        : '';
    selectedCurrency = model.currency;
  }

  void dispose() {
    titleController.dispose();
    notesController.dispose();
    costController.dispose();
  }
}
