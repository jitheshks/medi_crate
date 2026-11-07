import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return ExpenseRepository(hiveService: hiveService);
});
