import '../../../../core/storage/hive_service.dart';

/// ExpenseRepository manages profile-scoped medical expenses and payments.
class ExpenseRepository {
  final HiveService hiveService;

  ExpenseRepository({required this.hiveService});

  Future<List<Map<String, dynamic>>> getExpenses(String profileId) async {
    final box = hiveService.userBox;
    final expenses = <Map<String, dynamic>>[];

    for (final key in box.keys) {
      if (key.toString().startsWith('expense_')) {
        final val = box.get(key);
        if (val is Map) {
          final map = Map<String, dynamic>.from(val);
          if (map['profile_id'] == profileId) {
            expenses.add(map);
          }
        }
      }
    }

    return expenses;
  }

  Future<Map<String, dynamic>> saveExpense(
    String profileId,
    Map<String, dynamic> data,
  ) async {
    final id = data['id'] ?? 'expense_${DateTime.now().microsecondsSinceEpoch}';
    final payload = Map<String, dynamic>.from(data);
    payload['id'] = id;
    payload['profile_id'] = profileId;

    final box = hiveService.userBox;
    await box.put(id, payload);
    return payload;
  }

  Future<void> deleteExpense(String profileId, String expenseId) async {
    final box = hiveService.userBox;
    await box.delete(expenseId);
  }
}
