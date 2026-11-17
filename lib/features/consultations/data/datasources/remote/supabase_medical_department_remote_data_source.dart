import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/supabase/supabase_config.dart';
import '../../models/medical_department_model.dart';

/// SupabaseMedicalDepartmentRemoteDataSource fetches medical department reference data
/// from the PostgreSQL medical_departments table.
class SupabaseMedicalDepartmentRemoteDataSource {
  final SupabaseClient? customClient;

  SupabaseMedicalDepartmentRemoteDataSource({this.customClient});

  SupabaseClient get _client {
    final client = customClient;
    if (client != null) return client;
    if (SupabaseConfig.isInitialized) return SupabaseConfig.client;
    throw StateError(
      'SupabaseClient is not initialized and was not injected into SupabaseMedicalDepartmentRemoteDataSource.',
    );
  }

  /// Fetches all active medical departments ordered by display_order.
  Future<List<MedicalDepartmentModel>> fetchMedicalDepartments() async {
    final response = await _client
        .from('medical_departments')
        .select('id, name')
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return (response as List)
        .whereType<Map>()
        .map(
          (item) => MedicalDepartmentModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}
