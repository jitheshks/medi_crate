import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/remote/supabase_medical_department_remote_data_source.dart';
import '../../data/models/medical_department_model.dart';
import '../../data/repositories/medical_department_repository.dart';

final supabaseMedicalDepartmentRemoteDataSourceProvider =
    Provider<SupabaseMedicalDepartmentRemoteDataSource>((ref) {
  return SupabaseMedicalDepartmentRemoteDataSource();
});

final medicalDepartmentRepositoryProvider =
    Provider<MedicalDepartmentRepository>((ref) {
      final hive = ref.watch(hiveServiceProvider);
      final remote = ref.watch(supabaseMedicalDepartmentRemoteDataSourceProvider);
      final connectivity = ref.watch(connectivityServiceProvider);
      return MedicalDepartmentRepository(
        hiveService: hive,
        supabaseRemoteDataSource: remote,
        connectivityService: connectivity,
      );
    });

final medicalDepartmentsProvider = FutureProvider<List<MedicalDepartmentModel>>(
  (ref) async {
    final repo = ref.watch(medicalDepartmentRepositoryProvider);
    return repo.getMedicalDepartments();
  },
);
