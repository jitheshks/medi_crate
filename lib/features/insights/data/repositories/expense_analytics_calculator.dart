import 'package:intl/intl.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../consultations/data/models/consultation_model.dart';
import '../../../reports/data/models/report_model.dart';
import '../models/insights_summary_model.dart';

class ExpenseAnalyticsData {
  final double totalExpenses;
  final int recordsWithCostCount;
  final List<MonthlyExpenseBarItem> monthlyExpenses;
  final List<ExpenseBreakdownItem> expensesByCategory;
  final List<ExpenseBreakdownItem> expensesByHospital;
  final List<ExpenseBreakdownItem> expensesByDoctor;

  ExpenseAnalyticsData({
    required this.totalExpenses,
    required this.recordsWithCostCount,
    required this.monthlyExpenses,
    required this.expensesByCategory,
    required this.expensesByHospital,
    required this.expensesByDoctor,
  });
}

/// Computes unified expense analytics across standalone expenses, consultations fees, and appointment costs.
class ExpenseAnalyticsCalculator {
  static ExpenseAnalyticsData computeExpenseAnalytics({
    required List<Map<String, dynamic>> rawExpenses,
    required List<ConsultationModel> consultations,
    required List<AppointmentModel> appointments,
    required List<ReportModel> reports,
    required List<Map<String, dynamic>> rawHospitals,
  }) {
    double total = 0.0;
    int count = 0;

    final catMap = <String, double>{};
    final hospMap = <String, double>{};
    final docMap = <String, double>{};
    final monthlyMap = <String, double>{};

    void addMonthlyExpense(DateTime date, double amt) {
      final monthLabel = DateFormat('MMM').format(date);
      monthlyMap[monthLabel] = (monthlyMap[monthLabel] ?? 0.0) + amt;
    }

    // 1. Process Standalone Expenses
    for (final e in rawExpenses) {
      if (isLinkedClinicalExpense(e)) {
        continue;
      }
      final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt > 0) {
        total += amt;
        count++;
        final cat = e['category']?.toString() ?? 'General';
        catMap[cat] = (catMap[cat] ?? 0.0) + amt;

        final hosp =
            e['hospital']?.toString() ?? e['hospital_name']?.toString();
        if (hosp != null && hosp.isNotEmpty) {
          hospMap[hosp] = (hospMap[hosp] ?? 0.0) + amt;
        }

        final doc = e['doctor']?.toString() ?? e['doctor_name']?.toString();
        if (doc != null && doc.isNotEmpty) {
          docMap[doc] = (docMap[doc] ?? 0.0) + amt;
        }

        final rawDate = e['date'] ?? e['created_at'];
        final date = rawDate != null
            ? (DateTime.tryParse(rawDate.toString()) ?? DateTime.now())
            : DateTime.now();
        addMonthlyExpense(date, amt);
      }
    }

    // 2. Process Consultations Fees
    for (final c in consultations) {
      if (c.consultationFee != null && c.consultationFee! > 0) {
        final amt = c.consultationFee!;
        total += amt;
        count++;
        catMap['Consultations'] = (catMap['Consultations'] ?? 0.0) + amt;
        if (c.hospitalName != null && c.hospitalName!.isNotEmpty) {
          hospMap[c.hospitalName!] = (hospMap[c.hospitalName!] ?? 0.0) + amt;
        }
        if (c.doctorName.isNotEmpty) {
          docMap[c.doctorName] = (docMap[c.doctorName] ?? 0.0) + amt;
        }
        addMonthlyExpense(c.visitDate, amt);
      }
    }

    // 3. Process Appointments Costs
    for (final a in appointments) {
      if (a.cost != null && a.cost! > 0) {
        final amt = a.cost!;
        total += amt;
        count++;
        catMap['Appointments'] = (catMap['Appointments'] ?? 0.0) + amt;
        if (a.hospitalName != null && a.hospitalName!.isNotEmpty) {
          hospMap[a.hospitalName!] = (hospMap[a.hospitalName!] ?? 0.0) + amt;
        }
        if (a.doctorName.isNotEmpty) {
          docMap[a.doctorName] = (docMap[a.doctorName] ?? 0.0) + amt;
        }
        addMonthlyExpense(a.date, amt);
      }
    }

    // 4. Process Reports Expenses
    for (final r in reports) {
      if (r.expense != null && r.expense!.amount > 0) {
        final amt = r.expense!.amount;
        total += amt;
        count++;
        catMap['Lab Reports'] = (catMap['Lab Reports'] ?? 0.0) + amt;
        if (r.hospitalName != null && r.hospitalName!.isNotEmpty) {
          hospMap[r.hospitalName!] = (hospMap[r.hospitalName!] ?? 0.0) + amt;
        }
        if (r.doctorName != null && r.doctorName!.isNotEmpty) {
          docMap[r.doctorName!] = (docMap[r.doctorName!] ?? 0.0) + amt;
        }
        addMonthlyExpense(r.date, amt);
      }
    }

    if (total <= 0) {
      return ExpenseAnalyticsData(
        totalExpenses: 0.0,
        recordsWithCostCount: 0,
        monthlyExpenses: [],
        expensesByCategory: [],
        expensesByHospital: [],
        expensesByDoctor: [],
      );
    }

    final monthlyExpenses = monthlyMap.entries
        .map((e) => MonthlyExpenseBarItem(monthLabel: e.key, amount: e.value))
        .toList();

    return ExpenseAnalyticsData(
      totalExpenses: total,
      recordsWithCostCount: count,
      monthlyExpenses: monthlyExpenses,
      expensesByCategory: _mapToBreakdownItems(catMap, total),
      expensesByHospital: _mapToBreakdownItems(hospMap, total),
      expensesByDoctor: _mapToBreakdownItems(docMap, total),
    );
  }

  static List<ExpenseBreakdownItem> _mapToBreakdownItems(
    Map<String, double> map,
    double totalExpenses,
  ) {
    if (totalExpenses <= 0) return [];
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) {
      final pct = (e.value / totalExpenses).clamp(0.0, 1.0);
      return ExpenseBreakdownItem(
        label: e.key,
        amount: e.value,
        percentage: pct,
      );
    }).toList();
  }

  /// Returns true if [expense] is a synthetic mirror or linked record of a clinical
  /// appointment, consultation, or report to prevent double-counting against canonical clinical models.
  static bool isLinkedClinicalExpense(Map<String, dynamic> expense) {
    final id = expense['id']?.toString() ?? '';
    if (id.startsWith('expense_app_') ||
        id.startsWith('expense_con_') ||
        id.startsWith('expense_rep_')) {
      return true;
    }

    final refType = (expense['reference_type'] ?? expense['referenceType'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (refType == 'appointment' ||
        refType == 'consultation' ||
        refType == 'report') {
      return true;
    }

    return false;
  }
}
