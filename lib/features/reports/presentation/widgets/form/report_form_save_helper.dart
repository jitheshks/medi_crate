import '../../../data/models/report_model.dart';

class ReportFormSaveHelper {
  static ReportModel buildReportModel({
    required String? reportIdToEdit,
    required bool isEdit,
    required String profileId,
    required String title,
    required String selectedCategory,
    required DateTime selectedDate,
    required String? consultationId,
    required String? consultationTitle,
    required String? doctorId,
    required String? doctorName,
    required String? hospitalId,
    required String? hospitalName,
    required String notes,
    required List<ReportAttachmentModel> attachments,
    required bool enableExpense,
    required String expenseAmountText,
    required String expenseStatus,
    required String expenseDescText,
    String? expenseCurrency,
    String? clientUuid,
  }) {
    final timestamp = DateTime.now();
    final reportId = isEdit
        ? reportIdToEdit!
        : 'report_${timestamp.microsecondsSinceEpoch}';

    ReportExpenseModel? expense;
    if (enableExpense) {
      final amount = double.tryParse(expenseAmountText.trim()) ?? 0.0;
      if (amount > 0) {
        expense = ReportExpenseModel(
          id: 'exp_$reportId',
          amount: amount,
          currency: expenseCurrency ?? 'INR',
          status: expenseStatus,
          description: expenseDescText.trim().isNotEmpty
              ? expenseDescText.trim()
              : 'Expense for ${title.trim()}',
        );
      }
    }

    return ReportModel(
      id: reportId,
      profileId: profileId,
      title: title.trim(),
      category: selectedCategory,
      date: selectedDate,
      consultationId: consultationId,
      consultationTitle: consultationTitle,
      doctorId: doctorId,
      doctorName: doctorName,
      hospitalId: hospitalId,
      hospitalName: hospitalName,
      notes: notes.trim().isNotEmpty ? notes.trim() : null,
      attachments: attachments,
      expense: expense,
      clientUuid: clientUuid,
      createdAt: isEdit ? null : timestamp,
      updatedAt: timestamp,
    );
  }
}
