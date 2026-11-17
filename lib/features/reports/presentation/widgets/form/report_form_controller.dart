import 'package:material_ui/material_ui.dart';

import '../../../data/models/report_model.dart';
import 'report_attachment_helper.dart';

class ReportFormController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController expenseAmountController = TextEditingController();
  final TextEditingController expenseDescController = TextEditingController();

  String selectedCategory = 'LAB TEST';
  DateTime selectedDate = DateTime.now();

  String? consultationId;
  String? consultationTitle;
  String? doctorId;
  String? doctorName;
  String? hospitalId;
  String? hospitalName;

  List<ReportAttachmentModel> attachments = [];
  bool enableExpense = false;
  String expenseStatus = 'PAID';
  String? expenseCurrency;
  String? clientUuid;

  void populateFromReport(ReportModel report) {
    titleController.text = report.title;
    selectedCategory = report.category.toUpperCase();
    selectedDate = report.date;
    consultationId = report.consultationId;
    consultationTitle = report.consultationTitle;
    doctorId = report.doctorId;
    doctorName = report.doctorName;
    hospitalId = report.hospitalId;
    hospitalName = report.hospitalName;
    notesController.text = report.notes ?? '';
    attachments = List.from(report.attachments);
    clientUuid = report.clientUuid;

    if (report.expense != null) {
      enableExpense = true;
      expenseAmountController.text = report.expense!.amount > 0
          ? (report.expense!.amount % 1 == 0
                ? report.expense!.amount.toInt().toString()
                : report.expense!.amount.toString())
          : '';
      expenseStatus = report.expense!.status;
      expenseDescController.text = report.expense!.description ?? '';
      expenseCurrency = report.expense!.currency;
    }
  }

  Future<void> addAttachment(String profileId, VoidCallback onUpdate) async {
    final newAttachment = await ReportAttachmentHelper.pickAndSaveAttachment(
      profileId: profileId,
    );
    if (newAttachment != null) {
      attachments.add(newAttachment);
      onUpdate();
    }
  }

  void removeAttachment(int index, VoidCallback onUpdate) {
    attachments.removeAt(index);
    onUpdate();
  }

  void dispose() {
    titleController.dispose();
    notesController.dispose();
    expenseAmountController.dispose();
    expenseDescController.dispose();
  }
}
