import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_service.dart';
import '../datasources/remote/supabase_medical_department_remote_data_source.dart';
import '../models/medical_department_model.dart';

/// MedicalDepartmentRepository manages medical department reference directories
/// with offline Hive caching and Supabase integration.
class MedicalDepartmentRepository {
  static const String cacheKey = 'medical_departments_reference_cache';

  final HiveService hiveService;
  final SupabaseMedicalDepartmentRemoteDataSource? supabaseRemoteDataSource;
  final ConnectivityService? connectivityService;

  MedicalDepartmentRepository({
    required this.hiveService,
    this.supabaseRemoteDataSource,
    this.connectivityService,
    dynamic remoteDataSource,
  });

  /// Sorts departments alphabetically, placing 'OTHERS' at the very end.
  List<MedicalDepartmentModel> _sortDepartments(
    List<MedicalDepartmentModel> list,
  ) {
    final sorted = List<MedicalDepartmentModel>.from(list);
    sorted.sort((a, b) {
      final aName = a.name.trim().toUpperCase();
      final bName = b.name.trim().toUpperCase();
      if (aName == 'OTHERS') return 1;
      if (bName == 'OTHERS') return -1;
      return aName.compareTo(bName);
    });
    return sorted;
  }

  /// Fetches medical departments with remote pull and Hive caching.
  Future<List<MedicalDepartmentModel>> getMedicalDepartments({
    bool forceRefresh = false,
  }) async {
    final box = hiveService.userBox;

    // 1. If not forcing refresh, return immediately from local Hive cache if present
    if (!forceRefresh) {
      final cached = box.get(cacheKey);
      if (cached is Map && cached['departments'] is List) {
        final list = (cached['departments'] as List)
            .whereType<Map>()
            .map(
              (m) =>
                  MedicalDepartmentModel.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList();
        if (list.isNotEmpty) {
          return _sortDepartments(list);
        }
      }
    }

    if (connectivityService != null && supabaseRemoteDataSource != null) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          final remoteList =
              await supabaseRemoteDataSource!.fetchMedicalDepartments();
          if (remoteList.isNotEmpty) {
            final sorted = _sortDepartments(remoteList);
            final serialized = sorted.map((d) => d.toJson()).toList();
            await box.put(cacheKey, {'departments': serialized});
            return sorted;
          }
        } catch (_) {
          // Fallback to local cache on network or server error
        }
      }
    }

    // Read from local cache if remote fetch failed or offline
    final cached = box.get(cacheKey);
    if (cached is Map && cached['departments'] is List) {
      final list = (cached['departments'] as List)
          .whereType<Map>()
          .map(
            (m) =>
                MedicalDepartmentModel.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
      return _sortDepartments(list);
    }

    return const [];
  }
}
