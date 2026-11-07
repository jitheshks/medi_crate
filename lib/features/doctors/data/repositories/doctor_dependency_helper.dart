import '../../../../core/storage/hive_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../hospitals/data/models/hospital_model.dart';
import '../../../hospitals/data/repositories/hospital_repository.dart';
import '../models/doctor_hospital_relation.dart';
import '../models/doctor_model.dart';

class DoctorDependencyHelper {
  final HiveService hiveService;

  DoctorDependencyHelper({required this.hiveService});

  /// Calculates all dependent records linked to [doctorId] for [profileId].
  Future<EntityDependencies> getDoctorDependencies({
    required String profileId,
    required DoctorModel? doctor,
    required String doctorId,
  }) async {
    if (doctor == null) {
      return const EntityDependencies();
    }

    final box = hiveService.userBox;
    final doctorNameLower = doctor.name.trim().toLowerCase();

    final consultationHospitalIds = <String>{};
    int consultationCount = 0;
    int reportCount = 0;
    int appointmentCount = 0;

    for (final k in box.keys) {
      final kStr = k.toString();
      if (kStr.startsWith('consultation_') || kStr.startsWith('con_')) {
        final cVal = box.get(k);
        if (cVal is Map) {
          final cProfId = (cVal['profile_id'] ?? cVal['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            cProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final cDocId =
                cVal['doctor_id']?.toString() ?? cVal['doctorId']?.toString();
            final cDocName = (cVal['doctor_name'] ?? cVal['doctorName'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (IdUtils.matches(cDocId, doctorId) ||
                (cDocName.isNotEmpty && cDocName == doctorNameLower)) {
              consultationCount++;
              final hospId =
                  cVal['hospital_id']?.toString() ??
                  cVal['hospitalId']?.toString();
              if (hospId != null && hospId.isNotEmpty) {
                consultationHospitalIds.add(IdUtils.unprefix(hospId));
              }
            }
          }
        }
      } else if (kStr.startsWith('report_') || kStr.startsWith('rep_')) {
        final rVal = box.get(k);
        if (rVal is Map) {
          final rProfId = (rVal['profile_id'] ?? rVal['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            rProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final rDocId =
                rVal['doctor_id']?.toString() ?? rVal['doctorId']?.toString();
            final rDocName =
                (rVal['doctor_name'] ??
                        rVal['doctor'] ??
                        rVal['doctorName'] ??
                        '')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (IdUtils.matches(rDocId, doctorId) ||
                (rDocName.isNotEmpty && rDocName == doctorNameLower)) {
              reportCount++;
            }
          }
        }
      } else if (kStr.startsWith('appointment_') || kStr.startsWith('apt_')) {
        final aVal = box.get(k);
        if (aVal is Map) {
          final aProfId = (aVal['profile_id'] ?? aVal['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            aProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final aDocId =
                aVal['doctor_id']?.toString() ?? aVal['doctorId']?.toString();
            final aDocName = (aVal['doctor_name'] ?? aVal['doctorName'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (IdUtils.matches(aDocId, doctorId) ||
                (aDocName.isNotEmpty && aDocName == doctorNameLower)) {
              appointmentCount++;
            }
          }
        }
      }
    }

    final allHospitalKeys = <String>{};
    for (final hId in doctor.hospitalIds) {
      allHospitalKeys.add(IdUtils.unprefix(hId));
    }
    allHospitalKeys.addAll(consultationHospitalIds);

    return EntityDependencies(
      hospitals: allHospitalKeys.length,
      consultations: consultationCount,
      reports: reportCount,
      appointments: appointmentCount,
    );
  }

  /// Returns all practicing hospitals for [doctor], deriving both explicit
  /// links and consultation relationships.
  Future<List<PracticingHospitalInfo>> getPracticingHospitals(
    String profileId,
    DoctorModel doctor,
  ) async {
    final hospitalRepo = HospitalRepository(hiveService: hiveService);
    final allHospitals = await hospitalRepo.getHospitalModels(profileId);
    final box = hiveService.userBox;

    final consultationHospCounts = <String, int>{};
    final consultationHospNames = <String, String>{};
    final doctorNameLower = doctor.name.trim().toLowerCase();

    for (final k in box.keys) {
      final kStr = k.toString();
      if (kStr.startsWith('consultation_') || kStr.startsWith('con_')) {
        final cVal = box.get(k);
        if (cVal is Map) {
          final cProfId = (cVal['profile_id'] ?? cVal['profileId'])?.toString();
          if (IdUtils.matchesProfileId(
            cProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final cDocId =
                cVal['doctor_id']?.toString() ?? cVal['doctorId']?.toString();
            final cDocName = (cVal['doctor_name'] ?? cVal['doctorName'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (IdUtils.matches(cDocId, doctor.id) ||
                (cDocName.isNotEmpty && cDocName == doctorNameLower)) {
              final hospId =
                  cVal['hospital_id']?.toString() ??
                  cVal['hospitalId']?.toString();
              final hospName =
                  (cVal['hospital_name'] ?? cVal['hospitalName'] ?? '')
                      .toString()
                      .trim();
              if (hospId != null && hospId.isNotEmpty) {
                final unKey = IdUtils.unprefix(hospId);
                consultationHospCounts[unKey] =
                    (consultationHospCounts[unKey] ?? 0) + 1;
                if (hospName.isNotEmpty) {
                  consultationHospNames[unKey] = hospName;
                }
              } else if (hospName.isNotEmpty) {
                final nameKey = 'name_${hospName.toLowerCase()}';
                consultationHospCounts[nameKey] =
                    (consultationHospCounts[nameKey] ?? 0) + 1;
                consultationHospNames[nameKey] = hospName;
              }
            }
          }
        }
      }
    }

    final result = <PracticingHospitalInfo>[];
    final processedKeys = <String>{};

    for (final hosp in allHospitals) {
      final unKey = IdUtils.unprefix(hosp.id);
      final isDirect = IdUtils.contains(doctor.hospitalIds, hosp.id);
      final cCount =
          consultationHospCounts[unKey] ??
          consultationHospCounts['name_${hosp.name.trim().toLowerCase()}'] ??
          0;
      final isFromCon = cCount > 0;

      if (isDirect || isFromCon) {
        processedKeys.add(unKey);
        processedKeys.add('name_${hosp.name.trim().toLowerCase()}');
        result.add(
          PracticingHospitalInfo(
            hospital: hosp,
            isDirect: isDirect,
            isFromConsultation: isFromCon,
            consultationCount: cCount,
          ),
        );
      }
    }

    for (final entry in consultationHospCounts.entries) {
      if (!processedKeys.contains(entry.key) && entry.value > 0) {
        final fallbackName = consultationHospNames[entry.key] ?? 'Hospital';
        final fallbackId = entry.key.startsWith('name_')
            ? 'hosp_${entry.key.substring(5)}'
            : 'hospital_${entry.key}';
        result.add(
          PracticingHospitalInfo(
            hospital: HospitalModel(
              id: fallbackId,
              profileId: profileId,
              name: fallbackName,
            ),
            isDirect: false,
            isFromConsultation: true,
            consultationCount: entry.value,
          ),
        );
      }
    }

    return result;
  }
}
