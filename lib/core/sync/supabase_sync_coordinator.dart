import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/appointments/data/datasources/remote/supabase_appointment_remote_data_source.dart';
import '../../features/appointments/data/models/appointment_model.dart';
import '../../features/consultations/data/datasources/remote/supabase_consultation_remote_data_source.dart';
import '../../features/consultations/data/models/consultation_attachment.dart';
import '../../features/consultations/data/models/consultation_model.dart';
import '../../features/doctors/data/datasources/remote/supabase_doctor_remote_data_source.dart';
import '../../features/doctors/data/models/doctor_model.dart';
import '../../features/hospitals/data/datasources/remote/supabase_hospital_remote_data_source.dart';
import '../../features/hospitals/data/models/hospital_model.dart';
import '../../features/medicines/data/datasources/remote/supabase_medicine_remote_data_source.dart';
import '../../features/medicines/data/models/medicine_model.dart';
import '../../features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import '../../features/profile/data/models/profile_model.dart';
import '../../features/reports/data/datasources/remote/supabase_report_remote_data_source.dart';
import '../../features/reports/data/models/report_model.dart';
import '../../features/vitals/data/datasources/remote/supabase_vitals_remote_data_source.dart';
import '../../features/vitals/data/models/measurement_model.dart';
import '../exceptions/app_exception.dart';
import '../storage/hive_service.dart';
import '../storage/supabase_storage_service.dart';
import '../supabase/supabase_config.dart';
import '../utils/id_utils.dart';
import 'models/sync_queue_item.dart';

extension _IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// SupabaseSyncCoordinator manages native synchronization of queued offline mutations
/// directly to PostgreSQL and private Supabase Storage buckets.
///
/// Ensures:
/// 1. Authoritative user identity via active authenticated Supabase sessions.
/// 2. UUID and client_uuid idempotency to prevent duplicates across retries.
/// 3. Profile isolation and historical clinical immutability.
/// 4. Storage lifecycle orchestration for reports and consultations.
/// 5. Complete isolation from legacy Laravel REST endpoints.
class SupabaseSyncCoordinator {
  final HiveService hiveService;
  final SupabaseClient? customClient;
  final SupabaseStorageService? customStorageService;
  final SupabaseProfileRemoteDataSource? customProfileRemoteDataSource;
  final SupabaseDoctorRemoteDataSource? customDoctorRemoteDataSource;
  final SupabaseHospitalRemoteDataSource? customHospitalRemoteDataSource;
  final SupabaseAppointmentRemoteDataSource? customAppointmentRemoteDataSource;
  final SupabaseMedicineRemoteDataSource? customMedicineRemoteDataSource;
  final SupabaseVitalsRemoteDataSource? customVitalsRemoteDataSource;
  final SupabaseReportRemoteDataSource? customReportRemoteDataSource;
  final SupabaseConsultationRemoteDataSource? customConsultationRemoteDataSource;

  SupabaseSyncCoordinator({
    required this.hiveService,
    this.customClient,
    this.customStorageService,
    this.customProfileRemoteDataSource,
    this.customDoctorRemoteDataSource,
    this.customHospitalRemoteDataSource,
    this.customAppointmentRemoteDataSource,
    this.customMedicineRemoteDataSource,
    this.customVitalsRemoteDataSource,
    this.customReportRemoteDataSource,
    this.customConsultationRemoteDataSource,
  });

  SupabaseClient get _client => customClient ?? SupabaseConfig.client;

  SupabaseStorageService get storageService =>
      customStorageService ?? SupabaseStorageService(customClient: _client);

  SupabaseProfileRemoteDataSource get profileRemoteDataSource =>
      customProfileRemoteDataSource ??
      SupabaseProfileRemoteDataSource(
        customClient: _client,
        customStorageService: storageService,
      );

  SupabaseDoctorRemoteDataSource get doctorRemoteDataSource =>
      customDoctorRemoteDataSource ??
      SupabaseDoctorRemoteDataSource(customClient: _client);

  SupabaseHospitalRemoteDataSource get hospitalRemoteDataSource =>
      customHospitalRemoteDataSource ??
      SupabaseHospitalRemoteDataSource(customClient: _client);

  SupabaseAppointmentRemoteDataSource get appointmentRemoteDataSource =>
      customAppointmentRemoteDataSource ??
      SupabaseAppointmentRemoteDataSource(client: _client);

  SupabaseMedicineRemoteDataSource get medicineRemoteDataSource =>
      customMedicineRemoteDataSource ??
      SupabaseMedicineRemoteDataSource(client: _client);

  SupabaseVitalsRemoteDataSource get vitalsRemoteDataSource =>
      customVitalsRemoteDataSource ??
      SupabaseVitalsRemoteDataSource(client: _client);

  SupabaseReportRemoteDataSource get reportRemoteDataSource =>
      customReportRemoteDataSource ??
      SupabaseReportRemoteDataSource(
        client: _client,
        storageService: storageService,
      );

  SupabaseConsultationRemoteDataSource get consultationRemoteDataSource =>
      customConsultationRemoteDataSource ??
      SupabaseConsultationRemoteDataSource(
        client: _client,
      );

  /// Resolves the authenticated Supabase user ID for the active session, if any.
  String? get authenticatedUserId => _resolveAuthenticatedSessionUserId();

  /// Resolves authenticated session user ID strictly from the active Supabase session.
  /// Never trusts queued user IDs as the authoritative session identity.
  String? _resolveAuthenticatedSessionUserId([String? explicitUserId]) {
    String? sessionUserId;
    try {
      final user = _client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        sessionUserId = user.id.trim();
      }
    } catch (_) {}

    if (sessionUserId != null && sessionUserId.isNotEmpty) {
      if (explicitUserId != null &&
          explicitUserId.trim().isNotEmpty &&
          explicitUserId.trim() != sessionUserId) {
        // Explicit caller requested a different user than the active session; reject.
        return null;
      }
      return sessionUserId;
    }

    // No active session in _client.auth.currentUser: unauthenticated.
    return null;
  }

  /// Resolves the clean profile UUID for Supabase operations, rejecting foreign profile access.
  String? _resolveProfileUuid(String profileId, String ownerUserId) {
    final clean = IdUtils.unprefix(profileId).trim();
    try {
      final box = hiveService.profileBox;
      final raw =
          box.get(profileId) ?? box.get(clean) ?? box.get('prof_$clean');
      Map? direct;
      if (raw != null) {
        direct = raw;
      } else {
        for (final val in box.values) {
          final pId = (val['profile_id'] ?? val['id'])?.toString();
          if (pId != null &&
              (IdUtils.matches(pId, profileId) ||
                  IdUtils.matches(pId, clean))) {
            direct = val;
            break;
          }
        }
      }
      if (direct != null) {
        final profOwner = (direct['owner_user_id'] ??
                direct['ownerUserId'] ??
                direct['user_id'])
            ?.toString();
        if (profOwner != null &&
            profOwner.isNotEmpty &&
            !IdUtils.matches(profOwner, ownerUserId)) {
          return null;
        }

        final id = (direct['profile_id'] ?? direct['id'])?.toString();
        if (id != null && UuidUtils.isValidUuid(IdUtils.unprefix(id))) {
          return IdUtils.unprefix(id).trim();
        }
        final cUuid =
            (direct['client_uuid'] ?? direct['clientUuid'])?.toString();
        if (cUuid != null && UuidUtils.isValidUuid(cUuid)) {
          return cUuid.trim();
        }
      }
    } catch (_) {}

    if (UuidUtils.isValidUuid(clean)) return clean;
    return null;
  }

  /// Resolves the doctor UUID from local Hive cache if an item references a local ID.
  String? _resolveDoctorUuid(String? rawDoctorId) {
    if (rawDoctorId == null) return null;
    final clean = IdUtils.unprefix(rawDoctorId).trim();
    if (clean.isEmpty) return null;
    if (UuidUtils.isValidUuid(clean)) return clean;

    final direct = hiveService.userBox.get('doctor_$clean') ??
        hiveService.userBox.get(clean);
    if (direct is Map) {
      final id = (direct['id'] ?? direct['doctor_id'])?.toString();
      if (id != null && UuidUtils.isValidUuid(IdUtils.unprefix(id))) {
        return IdUtils.unprefix(id).trim();
      }
    }

    for (final k in hiveService.userBox.keys) {
      if (!k.toString().startsWith('doctor_')) continue;
      final raw = hiveService.userBox.get(k);
      if (raw is Map) {
        final cu = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
        final id = (raw['id'] ?? raw['doctor_id'])?.toString();
        if ((cu == clean || id == clean) &&
            id != null &&
            UuidUtils.isValidUuid(IdUtils.unprefix(id))) {
          return IdUtils.unprefix(id).trim();
        }
      }
    }
    return null;
  }

  /// Resolves the hospital UUID from local Hive cache if an item references a local ID.
  String? _resolveHospitalUuid(String? rawHospitalId) {
    if (rawHospitalId == null) return null;
    final clean = IdUtils.unprefix(rawHospitalId).trim();
    if (clean.isEmpty) return null;
    if (UuidUtils.isValidUuid(clean)) return clean;

    final direct = hiveService.userBox.get('hospital_$clean') ??
        hiveService.userBox.get(clean);
    if (direct is Map) {
      final id = (direct['id'] ?? direct['hospital_id'])?.toString();
      if (id != null && UuidUtils.isValidUuid(IdUtils.unprefix(id))) {
        return IdUtils.unprefix(id).trim();
      }
    }

    for (final k in hiveService.userBox.keys) {
      if (!k.toString().startsWith('hospital_')) continue;
      final raw = hiveService.userBox.get(k);
      if (raw is Map) {
        final cu = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
        final id = (raw['id'] ?? raw['hospital_id'])?.toString();
        if ((cu == clean || id == clean) &&
            id != null &&
            UuidUtils.isValidUuid(IdUtils.unprefix(id))) {
          return IdUtils.unprefix(id).trim();
        }
      }
    }
    return null;
  }

  /// Resolves the consultation UUID from local Hive cache if an item references a local ID.
  String? _resolveConsultationUuid(String? rawConsultationId) {
    if (rawConsultationId == null) return null;
    final clean = IdUtils.unprefix(rawConsultationId).trim();
    if (clean.isEmpty) return null;
    if (UuidUtils.isValidUuid(clean)) return clean;

    final direct = hiveService.userBox.get('consultation_$clean') ??
        hiveService.userBox.get(clean);
    if (direct is Map) {
      final id = (direct['id'] ?? direct['consultation_id'])?.toString();
      if (id != null && UuidUtils.isValidUuid(IdUtils.unprefix(id))) {
        return IdUtils.unprefix(id).trim();
      }
    }

    for (final k in hiveService.userBox.keys) {
      if (!k.toString().startsWith('consultation_')) continue;
      final raw = hiveService.userBox.get(k);
      if (raw is Map) {
        final cu = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
        final id = (raw['id'] ?? raw['consultation_id'])?.toString();
        if ((cu == clean || id == clean) &&
            id != null &&
            UuidUtils.isValidUuid(IdUtils.unprefix(id))) {
          return IdUtils.unprefix(id).trim();
        }
      }
    }
    return null;
  }

  /// Checks whether an entity dependency is currently pending in the sync queue.
  bool _isDependencyQueued(String entityType, String? rawId) {
    if (rawId == null) return false;
    final clean = IdUtils.unprefix(rawId).trim();
    if (clean.isEmpty) return false;

    final targetEntity = entityType.toLowerCase();
    for (final raw in hiveService.syncQueueBox.values) {
      final e = (raw['entity'] ?? '').toString().toLowerCase();
      if (!e.contains(targetEntity)) continue;

      final retryCount = raw['retry_count'] ?? raw['retryCount'] ?? 0;
      if (retryCount >= 99) continue;
      final status = (raw['status'] ?? '').toString().toLowerCase();
      if (status == 'completed' || status == 'synced') continue;

      final id = raw['id']?.toString();
      final payload = raw['payload'];
      if (payload is Map) {
        final pId = payload['id']?.toString();
        final cUuid =
            (payload['client_uuid'] ?? payload['clientUuid'])?.toString();
        if (clean == id || clean == pId || clean == cUuid) {
          return true;
        }
      } else if (clean == id) {
        return true;
      }
    }
    return false;
  }

  /// Derives or resolves an attachment UUID ensuring idempotency across retries.
  String _resolveAttachmentUuid(String rawAttId, String? fileUrl) {
    final cleanId = IdUtils.unprefix(rawAttId).trim();
    if (UuidUtils.isValidUuid(cleanId)) return cleanId;
    if (fileUrl != null && fileUrl.contains('/')) {
      final segments = fileUrl.split('/');
      final last = segments.isNotEmpty ? segments.last : '';
      if (last.length >= 37 && last[36] == '_') {
        final candidate = last.substring(0, 36);
        if (UuidUtils.isValidUuid(candidate)) return candidate;
      }
    }
    return UuidUtils.generateV4();
  }

  /// Dispatches a single queued mutation to the appropriate Supabase domain handler.
  Future<bool> processItem({
    required SyncQueueItem item,
    String? explicitOwnerUserId,
  }) async {
    final ownerUserId =
        _resolveAuthenticatedSessionUserId(explicitOwnerUserId);

    if (ownerUserId == null || ownerUserId.isEmpty) {
      item.status = 'auth_required';
      item.errorMessage =
          'Active authenticated Supabase session required to synchronize.';
      return false;
    }

    // Cross-user payload inspection: block mutation execution if queued for a different user
    final payloadUserId = (item.payload['owner_user_id'] ??
            item.payload['ownerUserId'] ??
            item.payload['user_id'] ??
            item.payload['userId'])
        ?.toString()
        .trim();

    if (payloadUserId != null &&
        payloadUserId.isNotEmpty &&
        !IdUtils.matches(payloadUserId, ownerUserId)) {
      item.status = 'deferred';
      item.errorMessage =
          'Cross-user mutation execution blocked: item belongs to $payloadUserId, but active session is $ownerUserId.';
      return false;
    }

    final entity = item.entity.trim().toLowerCase();

    try {
      if (entity == 'profile' ||
          entity == 'profiles' ||
          entity == 'family_member' ||
          entity == 'family_members') {
        return await _processProfileMutation(item, ownerUserId);
      }
      if (entity == 'hospital' || entity == 'hospitals') {
        return await _processHospitalMutation(item, ownerUserId);
      }
      if (entity == 'doctor' || entity == 'doctors') {
        return await _processDoctorMutation(item, ownerUserId);
      }
      if (entity == 'appointment' || entity == 'appointments') {
        return await _processAppointmentMutation(item, ownerUserId);
      }
      if (entity == 'medicine' || entity == 'medicines') {
        return await _processMedicineMutation(item, ownerUserId);
      }
      if (entity == 'measurement' ||
          entity == 'measurements' ||
          entity == 'vital' ||
          entity == 'vitals') {
        return await _processMeasurementMutation(item, ownerUserId);
      }
      if (entity == 'report' || entity == 'reports') {
        return await _processReportMutation(item, ownerUserId);
      }
      if (entity == 'consultation' || entity == 'consultations') {
        return await _processConsultationMutation(item, ownerUserId);
      }

      // Explicit failure for unsupported entities (dead-letter)
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = 'Unsupported Supabase entity: ${item.entity}';
      return false;
    } on AuthException catch (e) {
      item.status = 'auth_required';
      item.errorMessage = e.message;
      return false;
    } on UnauthorizedException catch (e) {
      item.status = 'auth_required';
      item.errorMessage = e.message;
      return false;
    } on NetworkException catch (e) {
      item.status = 'failed';
      item.errorMessage = e.message;
      return false;
    } on SocketException catch (e) {
      item.status = 'failed';
      item.errorMessage = 'Network connection unavailable: ${e.message}';
      return false;
    } on ValidationException catch (e) {
      // Constraint / schema violations cannot succeed on retry
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = e.message;
      return false;
    } on ConflictException catch (e) {
      // Handled via idempotency, but if unrecoverable, dead-letter
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = e.message;
      return false;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        item.status = 'auth_required';
        item.errorMessage = e.message;
        return false;
      }
      if (e.code == '23514' || e.code == '22P02') {
        // Permanent check constraint or invalid syntax/type failure
        item.status = 'failed';
        item.retryCount = 99;
        item.errorMessage = e.message;
        return false;
      }
      if (e.code == '23503') {
        if (item.retryCount >= 4) {
          // Retry budget exhausted for foreign-key dependency.
          // Dead-letter so it does not block the queue indefinitely.
          item.status = 'failed';
          item.retryCount = 99;
          item.errorMessage =
              'Foreign key dependency failed after retry exhaustion: ${e.message}';
          return false;
        }
        item.status = 'failed';
        item.errorMessage =
            'Foreign key dependency not satisfied: ${e.message}';
        return false;
      }
      item.status = 'failed';
      item.errorMessage = e.message;
      return false;
    } catch (e) {
      item.status = 'failed';
      item.errorMessage = e.toString();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 1. PROFILES
  // ---------------------------------------------------------------------------

  Future<bool> _processProfileMutation(
    SyncQueueItem item,
    String ownerUserId,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final profile = ProfileModel.fromMap(payload);

    if (operation == 'delete' || operation == 'hard_delete') {
      if (profile.isPrimary || profile.profileId.startsWith('prof_primary_')) {
        item.status = 'failed';
        item.retryCount = 99;
        item.errorMessage =
            'Primary profile deletion rejected: prohibited by system invariant';
        return false;
      }

      if (operation == 'hard_delete') {
        item.status = 'failed';
        item.retryCount = 99;
        item.errorMessage =
            'Direct hard-deletion of profiles is disabled to protect clinical history; use the archival workflow (is_archived = true) instead.';
        return false;
      }

      final cleanProfileId = _resolveProfileUuid(profile.profileId, ownerUserId) ??
          (UuidUtils.isValidUuid(IdUtils.unprefix(profile.profileId))
              ? IdUtils.unprefix(profile.profileId)
              : null);

      if (cleanProfileId != null) {
        // Authoritative archival workflow on Supabase preserves historical clinical records
        final archived = await profileRemoteDataSource.archiveProfile(
          profileId: cleanProfileId,
          ownerUserId: ownerUserId,
        );
        await hiveService.profileBox.put(archived.profileId, archived.toMap());
        await hiveService.profileBox.put(profile.profileId, archived.toMap());
        return true;
      } else if (_isDependencyQueued('profile', profile.profileId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for profile create mutation to resolve server ID before archival.';
        return false;
      } else {
        // Purely local provisional profile that never existed remotely
        await hiveService.profileBox.delete(profile.profileId);
        await hiveService.profileBox.delete(IdUtils.unprefix(profile.profileId));
        return true;
      }
    }

    if (operation == 'create') {
      final existingProfiles = await profileRemoteDataSource.fetchProfiles(
        ownerUserId: ownerUserId,
      );
      final clientUuid = profile.clientUuid ??
          (UuidUtils.isValidUuid(profile.profileId) ? profile.profileId : null);

      ProfileModel? match;
      if (clientUuid != null && clientUuid.isNotEmpty) {
        match = existingProfiles.firstWhereOrNull(
          (p) => p.clientUuid == clientUuid || p.profileId == clientUuid,
        );
      }
      if (match == null && profile.isPrimary) {
        match = existingProfiles.firstWhereOrNull((p) => p.isPrimary);
      }

      ProfileModel remoteProfile;
      if (match != null) {
        // Idempotency: record already created remotely in a prior attempt -> update
        remoteProfile = await profileRemoteDataSource.updateProfile(
          profile: profile.copyWith(profileId: match.profileId),
          ownerUserId: ownerUserId,
        );
      } else {
        remoteProfile = await profileRemoteDataSource.createFamilyProfile(
          profile: profile,
          ownerUserId: ownerUserId,
        );
      }

      final key = profile.profileId;
      await hiveService.profileBox.put(key, remoteProfile.toMap());
      await hiveService.profileBox
          .put(remoteProfile.profileId, remoteProfile.toMap());
      return true;
    }

    if (operation == 'update') {
      final remoteProfile = await profileRemoteDataSource.updateProfile(
        profile: profile,
        ownerUserId: ownerUserId,
      );
      final key = profile.profileId;
      await hiveService.profileBox.put(key, remoteProfile.toMap());
      await hiveService.profileBox
          .put(remoteProfile.profileId, remoteProfile.toMap());
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 2. HOSPITALS
  // ---------------------------------------------------------------------------

  Future<bool> _processHospitalMutation(
    SyncQueueItem item,
    String ownerUserId,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final rawProfileId = payload['profile_id'] ?? payload['profileId'];
    if (rawProfileId == null) {
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = 'Missing profile_id in hospital payload.';
      return false;
    }
    final profileUuid =
        _resolveProfileUuid(rawProfileId.toString(), ownerUserId);
    if (profileUuid == null) {
      item.status = 'deferred';
      item.errorMessage = 'Profile UUID not resolved yet.';
      return false;
    }

    final hospital =
        HospitalModel.fromJson(payload).copyWith(profileId: profileUuid);
    final cleanId = IdUtils.unprefix(hospital.id).trim();

    if (operation == 'delete') {
      String? targetId = UuidUtils.isValidUuid(cleanId) ? cleanId : null;
      final cUuid = hospital.clientUuid;
      if (targetId == null && cUuid != null && cUuid.isNotEmpty) {
        for (final k in hiveService.userBox.keys) {
          if (!k.toString().startsWith('hospital_')) continue;
          final raw = hiveService.userBox.get(k);
          if (raw is Map) {
            final u = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
            final hid = (raw['id'] ?? raw['hospital_id'])?.toString();
            if (u == cUuid && hid != null && UuidUtils.isValidUuid(IdUtils.unprefix(hid))) {
              targetId = IdUtils.unprefix(hid);
              break;
            }
          }
        }
        if (targetId == null) {
          try {
            final remoteList = await hospitalRemoteDataSource.fetchHospitals(
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            final match = remoteList.firstWhereOrNull(
              (h) => h.clientUuid == cUuid,
            );
            if (match != null) targetId = match.id;
          } catch (_) {}
        }
      }

      if (targetId != null) {
        await hospitalRemoteDataSource.deleteHospital(
          hospitalId: targetId,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
        await hiveService.userBox.delete('hospital_$targetId');
      }
      await hiveService.userBox.delete('hospital_$cleanId');
      await hiveService.userBox.delete(hospital.id);
      return true;
    }

    final clientUuid = hospital.clientUuid ??
        (UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4());

    if (operation == 'create') {
      final remoteList = await hospitalRemoteDataSource.fetchHospitals(
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      final match = remoteList.firstWhereOrNull(
        (h) =>
            (h.clientUuid != null && h.clientUuid == clientUuid) ||
            h.id == cleanId,
      );

      HospitalModel remoteHospital;
      if (match != null) {
        remoteHospital = await hospitalRemoteDataSource.updateHospital(
          hospital: hospital.copyWith(id: match.id, clientUuid: clientUuid),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      } else {
        remoteHospital = await hospitalRemoteDataSource.createHospital(
          hospital: hospital.copyWith(clientUuid: clientUuid),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      }

      await _reconcileUserBox(
        'hospital_',
        hospital.id,
        remoteHospital.id,
        remoteHospital.toJson(),
      );
      return true;
    }

    if (operation == 'update') {
      final remoteHospital = await hospitalRemoteDataSource.updateHospital(
        hospital: hospital.copyWith(id: cleanId),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      await _reconcileUserBox(
        'hospital_',
        hospital.id,
        remoteHospital.id,
        remoteHospital.toJson(),
      );
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 3. DOCTORS
  // ---------------------------------------------------------------------------

  Future<bool> _processDoctorMutation(
    SyncQueueItem item,
    String ownerUserId,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final rawProfileId = payload['profile_id'] ?? payload['profileId'];
    if (rawProfileId == null) {
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = 'Missing profile_id in doctor payload.';
      return false;
    }
    final profileUuid =
        _resolveProfileUuid(rawProfileId.toString(), ownerUserId);
    if (profileUuid == null) {
      item.status = 'deferred';
      item.errorMessage = 'Profile UUID not resolved yet.';
      return false;
    }

    final doctor =
        DoctorModel.fromJson(payload).copyWith(profileId: profileUuid);
    final cleanId = IdUtils.unprefix(doctor.id).trim();

    if (operation == 'delete') {
      String? targetId = UuidUtils.isValidUuid(cleanId) ? cleanId : null;
      final cUuid = doctor.clientUuid;
      if (targetId == null && cUuid != null && cUuid.isNotEmpty) {
        for (final k in hiveService.userBox.keys) {
          if (!k.toString().startsWith('doctor_')) continue;
          final raw = hiveService.userBox.get(k);
          if (raw is Map) {
            final u = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
            final did = (raw['id'] ?? raw['doctor_id'])?.toString();
            if (u == cUuid && did != null && UuidUtils.isValidUuid(IdUtils.unprefix(did))) {
              targetId = IdUtils.unprefix(did);
              break;
            }
          }
        }
        if (targetId == null) {
          try {
            final remoteList = await doctorRemoteDataSource.fetchDoctors(
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            final match = remoteList.firstWhereOrNull(
              (d) => d.clientUuid == cUuid,
            );
            if (match != null) targetId = match.id;
          } catch (_) {}
        }
      }

      if (targetId != null) {
        await doctorRemoteDataSource.deleteDoctor(
          doctorId: targetId,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
        await hiveService.userBox.delete('doctor_$targetId');
      }
      await hiveService.userBox.delete('doctor_$cleanId');
      await hiveService.userBox.delete(doctor.id);
      return true;
    }

    final clientUuid = doctor.clientUuid ??
        (UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4());

    // Resolve hospital affiliations:
    final resolvedHospIds = <String>[];
    for (final rawHId in doctor.hospitalIds) {
      final cleanHId = IdUtils.unprefix(rawHId).trim();
      if (UuidUtils.isValidUuid(cleanHId)) {
        resolvedHospIds.add(cleanHId);
      } else {
        final mappedHosp = _resolveHospitalUuid(cleanHId);
        if (mappedHosp != null) {
          resolvedHospIds.add(mappedHosp);
        } else if (_isDependencyQueued('hospital', cleanHId)) {
          item.status = 'deferred';
          item.errorMessage =
              'Waiting for hospital dependency ($cleanHId) to sync.';
          return false;
        }
      }
    }

    final resolvedDoctor = doctor.copyWith(
      hospitalIds: resolvedHospIds,
      clientUuid: clientUuid,
    );

    if (operation == 'create') {
      final remoteList = await doctorRemoteDataSource.fetchDoctors(
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      final match = remoteList.firstWhereOrNull(
        (d) =>
            (d.clientUuid != null && d.clientUuid == clientUuid) ||
            d.id == cleanId,
      );

      DoctorModel remoteDoctor;
      if (match != null) {
        remoteDoctor = await doctorRemoteDataSource.updateDoctor(
          doctor: resolvedDoctor.copyWith(id: match.id),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      } else {
        remoteDoctor = await doctorRemoteDataSource.createDoctor(
          doctor: resolvedDoctor,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      }

      await _reconcileUserBox(
        'doctor_',
        doctor.id,
        remoteDoctor.id,
        remoteDoctor.toJson(),
      );
      return true;
    }

    if (operation == 'update') {
      final remoteDoctor = await doctorRemoteDataSource.updateDoctor(
        doctor: resolvedDoctor.copyWith(id: cleanId),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      await _reconcileUserBox(
        'doctor_',
        doctor.id,
        remoteDoctor.id,
        remoteDoctor.toJson(),
      );
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 4. APPOINTMENTS
  // ---------------------------------------------------------------------------

  Future<bool> _processAppointmentMutation(
    SyncQueueItem item,
    String ownerUserId,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final rawProfileId = payload['profile_id'] ?? payload['profileId'];
    if (rawProfileId == null) {
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = 'Missing profile_id in appointment payload.';
      return false;
    }
    final profileUuid =
        _resolveProfileUuid(rawProfileId.toString(), ownerUserId);
    if (profileUuid == null) {
      item.status = 'deferred';
      item.errorMessage = 'Profile UUID not resolved yet.';
      return false;
    }

    final appt =
        AppointmentModel.fromJson(payload).copyWith(profileId: profileUuid);
    final cleanId = IdUtils.unprefix(appt.id).trim();

    if (operation == 'delete') {
      String? targetId = UuidUtils.isValidUuid(cleanId) ? cleanId : null;
      final cUuid = appt.clientUuid;
      if (targetId == null && cUuid != null && cUuid.isNotEmpty) {
        for (final k in hiveService.userBox.keys) {
          if (!k.toString().startsWith('appointment_')) continue;
          final raw = hiveService.userBox.get(k);
          if (raw is Map) {
            final u = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
            final aid = raw['id']?.toString();
            if (u == cUuid && aid != null && UuidUtils.isValidUuid(IdUtils.unprefix(aid))) {
              targetId = IdUtils.unprefix(aid);
              break;
            }
          }
        }
        if (targetId == null) {
          try {
            final remoteList = await appointmentRemoteDataSource.fetchAppointments(
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            final match = remoteList.firstWhereOrNull(
              (a) => a.clientUuid == cUuid,
            );
            if (match != null) targetId = match.id;
          } catch (_) {}
        }
      }

      if (targetId != null) {
        await appointmentRemoteDataSource.deleteAppointment(
          appointmentId: targetId,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
        await hiveService.userBox.delete('appointment_$targetId');
      }
      await hiveService.userBox.delete('appointment_$cleanId');
      await hiveService.userBox.delete(appt.id);
      return true;
    }

    final clientUuid = appt.clientUuid ??
        (UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4());

    // Resolve doctor and hospital dependencies if provided
    String? resolvedDoctorId = appt.doctorId != null
        ? IdUtils.unprefix(appt.doctorId!).trim()
        : null;
    if (resolvedDoctorId != null && !UuidUtils.isValidUuid(resolvedDoctorId)) {
      final mappedDoc = _resolveDoctorUuid(resolvedDoctorId);
      if (mappedDoc != null) {
        resolvedDoctorId = mappedDoc;
      } else if (_isDependencyQueued('doctor', resolvedDoctorId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for doctor dependency ($resolvedDoctorId) to sync.';
        return false;
      } else {
        resolvedDoctorId = null;
      }
    }

    String? resolvedHospitalId = appt.hospitalId != null
        ? IdUtils.unprefix(appt.hospitalId!).trim()
        : null;
    if (resolvedHospitalId != null &&
        !UuidUtils.isValidUuid(resolvedHospitalId)) {
      final mappedHosp = _resolveHospitalUuid(resolvedHospitalId);
      if (mappedHosp != null) {
        resolvedHospitalId = mappedHosp;
      } else if (_isDependencyQueued('hospital', resolvedHospitalId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for hospital dependency ($resolvedHospitalId) to sync.';
        return false;
      } else {
        resolvedHospitalId = null;
      }
    }

    final resolvedAppt = appt.copyWith(
      doctorId: resolvedDoctorId,
      hospitalId: resolvedHospitalId,
      clientUuid: clientUuid,
    );

    if (operation == 'create') {
      final remoteList = await appointmentRemoteDataSource.fetchAppointments(
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      final match = remoteList.firstWhereOrNull(
        (a) =>
            (a.clientUuid != null && a.clientUuid == clientUuid) ||
            a.id == cleanId,
      );

      AppointmentModel remoteAppt;
      if (match != null) {
        remoteAppt = await appointmentRemoteDataSource.updateAppointment(
          appointment: resolvedAppt.copyWith(id: match.id),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      } else {
        remoteAppt = await appointmentRemoteDataSource.createAppointment(
          appointment: resolvedAppt,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      }

      await _reconcileUserBox(
        'appointment_',
        appt.id,
        remoteAppt.id,
        remoteAppt.toJson(),
      );
      return true;
    }

    if (operation == 'update') {
      final remoteAppt = await appointmentRemoteDataSource.updateAppointment(
        appointment: resolvedAppt.copyWith(id: cleanId),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      await _reconcileUserBox(
        'appointment_',
        appt.id,
        remoteAppt.id,
        remoteAppt.toJson(),
      );
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 5. MEDICINES
  // ---------------------------------------------------------------------------

  Future<bool> _processMedicineMutation(
    SyncQueueItem item,
    String ownerUserId,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final rawProfileId = payload['profile_id'] ?? payload['profileId'];
    if (rawProfileId == null) {
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = 'Missing profile_id in medicine payload.';
      return false;
    }
    final profileUuid =
        _resolveProfileUuid(rawProfileId.toString(), ownerUserId);
    if (profileUuid == null) {
      item.status = 'deferred';
      item.errorMessage = 'Profile UUID not resolved yet.';
      return false;
    }

    final medicine =
        MedicineModel.fromJson(payload).copyWith(profileId: profileUuid);
    final cleanId = IdUtils.unprefix(medicine.id).trim();

    if (operation == 'delete') {
      String? targetId = UuidUtils.isValidUuid(cleanId) ? cleanId : null;
      final cUuid = medicine.clientUuid;
      if (targetId == null && cUuid != null && cUuid.isNotEmpty) {
        for (final k in hiveService.userBox.keys) {
          if (!k.toString().startsWith('medicine_')) continue;
          final raw = hiveService.userBox.get(k);
          if (raw is Map) {
            final u = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
            final mid = raw['id']?.toString();
            if (u == cUuid && mid != null && UuidUtils.isValidUuid(IdUtils.unprefix(mid))) {
              targetId = IdUtils.unprefix(mid);
              break;
            }
          }
        }
        if (targetId == null) {
          try {
            final remoteList = await medicineRemoteDataSource.fetchMedicines(
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            final match = remoteList.firstWhereOrNull(
              (m) => m.clientUuid == cUuid,
            );
            if (match != null) targetId = match.id;
          } catch (_) {}
        }
      }

      if (targetId != null) {
        await medicineRemoteDataSource.deleteMedicine(
          medicineId: targetId,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
        await hiveService.userBox.delete('medicine_$targetId');
      }
      await hiveService.userBox.delete('medicine_$cleanId');
      await hiveService.userBox.delete(medicine.id);
      return true;
    }

    final clientUuid = medicine.clientUuid ??
        (UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4());

    // Resolve linked consultation dependency if provided
    String? resolvedConsultationId = medicine.linkedConsultationId != null
        ? IdUtils.unprefix(medicine.linkedConsultationId!).trim()
        : null;
    if (resolvedConsultationId != null &&
        !UuidUtils.isValidUuid(resolvedConsultationId)) {
      final mappedConsultation =
          _resolveConsultationUuid(resolvedConsultationId);
      if (mappedConsultation != null) {
        resolvedConsultationId = mappedConsultation;
      } else if (_isDependencyQueued('consultation', resolvedConsultationId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for consultation dependency ($resolvedConsultationId) to sync.';
        return false;
      } else {
        resolvedConsultationId = null;
      }
    }

    final resolvedMedicine = medicine.copyWith(
      linkedConsultationId: resolvedConsultationId,
      clientUuid: clientUuid,
    );

    if (operation == 'create') {
      final remoteList = await medicineRemoteDataSource.fetchMedicines(
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      final match = remoteList.firstWhereOrNull(
        (m) =>
            (m.clientUuid != null && m.clientUuid == clientUuid) ||
            m.id == cleanId,
      );

      MedicineModel remoteMed;
      if (match != null) {
        remoteMed = await medicineRemoteDataSource.updateMedicine(
          medicine: resolvedMedicine.copyWith(id: match.id),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      } else {
        remoteMed = await medicineRemoteDataSource.createMedicine(
          medicine: resolvedMedicine,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      }

      await _reconcileUserBox(
        'medicine_',
        medicine.id,
        remoteMed.id,
        remoteMed.toJson(),
      );
      return true;
    }

    if (operation == 'update') {
      final remoteMed = await medicineRemoteDataSource.updateMedicine(
        medicine: resolvedMedicine.copyWith(id: cleanId),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      await _reconcileUserBox(
        'medicine_',
        medicine.id,
        remoteMed.id,
        remoteMed.toJson(),
      );
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 6. VITALS / MEASUREMENTS
  // ---------------------------------------------------------------------------

  Future<bool> _processMeasurementMutation(
    SyncQueueItem item,
    String ownerUserId,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final rawProfileId = payload['profile_id'] ?? payload['profileId'];
    if (rawProfileId == null) {
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = 'Missing profile_id in measurement payload.';
      return false;
    }
    final profileUuid =
        _resolveProfileUuid(rawProfileId.toString(), ownerUserId);
    if (profileUuid == null) {
      item.status = 'deferred';
      item.errorMessage = 'Profile UUID not resolved yet.';
      return false;
    }

    final vital =
        MeasurementModel.fromMap(payload).copyWith(profileId: profileUuid);
    final cleanId = IdUtils.unprefix(vital.id).trim();

    if (operation == 'delete') {
      String? targetId = UuidUtils.isValidUuid(cleanId) ? cleanId : null;
      final cUuid = vital.clientUuid;
      if (targetId == null && cUuid != null && cUuid.isNotEmpty) {
        for (final k in hiveService.userBox.keys) {
          if (!k.toString().startsWith('measurement_')) continue;
          final raw = hiveService.userBox.get(k);
          if (raw is Map) {
            final u = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
            final mid = raw['id']?.toString();
            if (u == cUuid && mid != null && UuidUtils.isValidUuid(IdUtils.unprefix(mid))) {
              targetId = IdUtils.unprefix(mid);
              break;
            }
          }
        }
        if (targetId == null) {
          try {
            final remoteList = await vitalsRemoteDataSource.fetchMeasurements(
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            final match = remoteList.firstWhereOrNull(
              (m) => m.clientUuid == cUuid,
            );
            if (match != null) targetId = match.id;
          } catch (_) {}
        }
      }

      if (targetId != null) {
        await vitalsRemoteDataSource.deleteMeasurement(
          measurementId: targetId,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
        await hiveService.userBox.delete('measurement_$targetId');
      }
      await hiveService.userBox.delete('measurement_$cleanId');
      await hiveService.userBox.delete(vital.id);
      return true;
    }

    final clientUuid = vital.clientUuid ??
        (UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4());

    if (operation == 'create') {
      final remoteList = await vitalsRemoteDataSource.fetchMeasurements(
        ownerUserId: ownerUserId,
        profileId: profileUuid,
        type: vital.type,
      );
      final match = remoteList.firstWhereOrNull(
        (m) =>
            (m.clientUuid != null && m.clientUuid == clientUuid) ||
            m.id == cleanId,
      );

      MeasurementModel remoteVital;
      if (match != null) {
        // Idempotency: preserve immutable historical recorded timestamp
        remoteVital = await vitalsRemoteDataSource.updateMeasurement(
          measurement: vital.copyWith(
            id: match.id,
            clientUuid: clientUuid,
            recordedAt: match.recordedAt,
          ),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      } else {
        remoteVital = await vitalsRemoteDataSource.createMeasurement(
          measurement: vital.copyWith(clientUuid: clientUuid),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      }

      await _reconcileUserBox(
        'measurement_',
        vital.id,
        remoteVital.id,
        remoteVital.toMap(),
      );
      return true;
    }

    if (operation == 'update') {
      final remoteVital = await vitalsRemoteDataSource.updateMeasurement(
        measurement: vital.copyWith(id: cleanId),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      await _reconcileUserBox(
        'measurement_',
        vital.id,
        remoteVital.id,
        remoteVital.toMap(),
      );
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 7. REPORTS
  // ---------------------------------------------------------------------------

  Future<bool> _processReportMutation(
    SyncQueueItem item,
    String ownerUserId,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final rawProfileId = payload['profile_id'] ?? payload['profileId'];
    if (rawProfileId == null) {
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = 'Missing profile_id in report payload.';
      return false;
    }
    final profileUuid =
        _resolveProfileUuid(rawProfileId.toString(), ownerUserId);
    if (profileUuid == null) {
      item.status = 'deferred';
      item.errorMessage = 'Profile UUID not resolved yet.';
      return false;
    }

    final report =
        ReportModel.fromJson(payload).copyWith(profileId: profileUuid);
    final cleanId = IdUtils.unprefix(report.id).trim();

    if (operation == 'delete') {
      String? targetId = UuidUtils.isValidUuid(cleanId) ? cleanId : null;
      final cUuid = report.clientUuid;
      if (targetId == null && cUuid != null && cUuid.isNotEmpty) {
        for (final k in hiveService.userBox.keys) {
          if (!k.toString().startsWith('report_')) continue;
          final raw = hiveService.userBox.get(k);
          if (raw is Map) {
            final u = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
            final rid = raw['id']?.toString();
            if (u == cUuid && rid != null && UuidUtils.isValidUuid(IdUtils.unprefix(rid))) {
              targetId = IdUtils.unprefix(rid);
              break;
            }
          }
        }
        if (targetId == null) {
          try {
            final remoteList = await reportRemoteDataSource.fetchReports(
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            final match = remoteList.firstWhereOrNull(
              (r) => r.clientUuid == cUuid,
            );
            if (match != null) targetId = match.id;
          } catch (_) {}
        }
      }

      if (targetId != null) {
        await reportRemoteDataSource.deleteReport(
          reportId: targetId,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
        await hiveService.userBox.delete('report_$targetId');
      }
      await hiveService.userBox.delete('report_$cleanId');
      await hiveService.userBox.delete(report.id);
      return true;
    }

    final clientUuid = report.clientUuid ??
        (UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4());
    final effectiveReportId =
        UuidUtils.isValidUuid(cleanId) ? cleanId : clientUuid;

    // Resolve consultation, doctor, and hospital dependencies if provided
    String? resolvedConsultationId = report.consultationId != null
        ? IdUtils.unprefix(report.consultationId!).trim()
        : null;
    if (resolvedConsultationId != null &&
        !UuidUtils.isValidUuid(resolvedConsultationId)) {
      final mappedConsultation =
          _resolveConsultationUuid(resolvedConsultationId);
      if (mappedConsultation != null) {
        resolvedConsultationId = mappedConsultation;
      } else if (_isDependencyQueued('consultation', resolvedConsultationId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for consultation dependency ($resolvedConsultationId) to sync.';
        return false;
      } else {
        resolvedConsultationId = null;
      }
    }

    String? resolvedDoctorId = report.doctorId != null
        ? IdUtils.unprefix(report.doctorId!).trim()
        : null;
    if (resolvedDoctorId != null && !UuidUtils.isValidUuid(resolvedDoctorId)) {
      final mappedDoc = _resolveDoctorUuid(resolvedDoctorId);
      if (mappedDoc != null) {
        resolvedDoctorId = mappedDoc;
      } else if (_isDependencyQueued('doctor', resolvedDoctorId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for doctor dependency ($resolvedDoctorId) to sync.';
        return false;
      } else {
        resolvedDoctorId = null;
      }
    }

    String? resolvedHospitalId = report.hospitalId != null
        ? IdUtils.unprefix(report.hospitalId!).trim()
        : null;
    if (resolvedHospitalId != null &&
        !UuidUtils.isValidUuid(resolvedHospitalId)) {
      final mappedHosp = _resolveHospitalUuid(resolvedHospitalId);
      if (mappedHosp != null) {
        resolvedHospitalId = mappedHosp;
      } else if (_isDependencyQueued('hospital', resolvedHospitalId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for hospital dependency ($resolvedHospitalId) to sync.';
        return false;
      } else {
        resolvedHospitalId = null;
      }
    }

    final resolvedReport = report.copyWith(
      consultationId: resolvedConsultationId,
      doctorId: resolvedDoctorId,
      hospitalId: resolvedHospitalId,
      clientUuid: clientUuid,
    );

    if (operation == 'create') {
      final remoteList = await reportRemoteDataSource.fetchReports(
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      final match = remoteList.firstWhereOrNull(
        (r) =>
            (r.clientUuid != null && r.clientUuid == clientUuid) ||
            r.id == cleanId,
      );

      final isAlreadyCreated = match != null;
      final targetReportId = isAlreadyCreated ? match.id : effectiveReportId;

      if (!isAlreadyCreated) {
        // Step A: Create parent report in PostgREST first to satisfy Storage RLS
        await reportRemoteDataSource.createReport(
          report: resolvedReport.copyWith(
            id: targetReportId,
            attachments: [],
          ),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      }

      // Step B: Upload any attachments with local files on disk
      final uploadedAttachments = <ReportAttachmentModel>[];
      for (final att in report.attachments) {
        if (att.filePath != null &&
            File(att.filePath!).existsSync() &&
            (att.fileUrl == null ||
                att.fileUrl!.isEmpty ||
                att.fileUrl!.startsWith('/') ||
                att.fileUrl!.startsWith('file:') ||
                !att.fileUrl!.contains('/'))) {
          final attUuid = _resolveAttachmentUuid(att.id, att.fileUrl);
          final storagePath = await reportRemoteDataSource.uploadAttachmentFile(
            userId: ownerUserId,
            reportId: targetReportId,
            file: File(att.filePath!),
            customAttachmentId: attUuid,
            fileName: att.name,
          );
          uploadedAttachments
              .add(att.copyWith(id: attUuid, fileUrl: storagePath));
        } else {
          uploadedAttachments.add(att);
        }
      }

      // Step C: Update report with attachments & expense
      final remoteReport = await reportRemoteDataSource.updateReport(
        report: resolvedReport.copyWith(
          id: targetReportId,
          attachments: uploadedAttachments,
        ),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );

      // Preserve local filePath for cached files
      final mergedAttachments = <ReportAttachmentModel>[];
      for (final rAtt in remoteReport.attachments) {
        final localMatch = report.attachments.firstWhereOrNull(
          (lAtt) => lAtt.id == rAtt.id || lAtt.name == rAtt.name,
        );
        mergedAttachments.add(rAtt.copyWith(filePath: localMatch?.filePath));
      }

      final finalReport =
          remoteReport.copyWith(attachments: mergedAttachments);
      await _reconcileUserBox(
        'report_',
        report.id,
        finalReport.id,
        finalReport.toJson(),
      );
      return true;
    }

    if (operation == 'update') {
      final uploadedAttachments = <ReportAttachmentModel>[];
      for (final att in report.attachments) {
        if (att.filePath != null &&
            File(att.filePath!).existsSync() &&
            (att.fileUrl == null ||
                att.fileUrl!.isEmpty ||
                att.fileUrl!.startsWith('/') ||
                att.fileUrl!.startsWith('file:') ||
                !att.fileUrl!.contains('/'))) {
          final attUuid = _resolveAttachmentUuid(att.id, att.fileUrl);
          final storagePath = await reportRemoteDataSource.uploadAttachmentFile(
            userId: ownerUserId,
            reportId: cleanId,
            file: File(att.filePath!),
            customAttachmentId: attUuid,
            fileName: att.name,
          );
          uploadedAttachments
              .add(att.copyWith(id: attUuid, fileUrl: storagePath));
        } else {
          uploadedAttachments.add(att);
        }
      }

      final remoteReport = await reportRemoteDataSource.updateReport(
        report: resolvedReport.copyWith(
          id: cleanId,
          attachments: uploadedAttachments,
        ),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );

      final mergedAttachments = <ReportAttachmentModel>[];
      for (final rAtt in remoteReport.attachments) {
        final localMatch = report.attachments.firstWhereOrNull(
          (lAtt) => lAtt.id == rAtt.id || lAtt.name == rAtt.name,
        );
        mergedAttachments.add(rAtt.copyWith(filePath: localMatch?.filePath));
      }

      final finalReport =
          remoteReport.copyWith(attachments: mergedAttachments);
      await _reconcileUserBox(
        'report_',
        report.id,
        finalReport.id,
        finalReport.toJson(),
      );
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // 8. CONSULTATIONS
  // ---------------------------------------------------------------------------

  Future<bool> _processConsultationMutation(
    SyncQueueItem item,
    String ownerUserId,
  ) async {
    final payload = Map<String, dynamic>.from(item.payload);
    final operation = item.operation.toLowerCase();
    final rawProfileId = payload['profile_id'] ?? payload['profileId'];
    if (rawProfileId == null) {
      item.status = 'failed';
      item.retryCount = 99;
      item.errorMessage = 'Missing profile_id in consultation payload.';
      return false;
    }
    final profileUuid =
        _resolveProfileUuid(rawProfileId.toString(), ownerUserId);
    if (profileUuid == null) {
      item.status = 'deferred';
      item.errorMessage = 'Profile UUID not resolved yet.';
      return false;
    }

    final consultation =
        ConsultationModel.fromJson(payload).copyWith(profileId: profileUuid);
    final cleanId = IdUtils.unprefix(consultation.id).trim();

    if (operation == 'delete') {
      String? targetId = UuidUtils.isValidUuid(cleanId) ? cleanId : null;
      final cUuid = consultation.clientUuid;
      if (targetId == null && cUuid != null && cUuid.isNotEmpty) {
        for (final k in hiveService.userBox.keys) {
          if (!k.toString().startsWith('consultation_')) continue;
          final raw = hiveService.userBox.get(k);
          if (raw is Map) {
            final u = (raw['client_uuid'] ?? raw['clientUuid'])?.toString();
            final cid = raw['id']?.toString();
            if (u == cUuid && cid != null && UuidUtils.isValidUuid(IdUtils.unprefix(cid))) {
              targetId = IdUtils.unprefix(cid);
              break;
            }
          }
        }
        if (targetId == null) {
          try {
            final remoteList = await consultationRemoteDataSource.fetchConsultations(
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            final match = remoteList.firstWhereOrNull(
              (c) => c.clientUuid == cUuid,
            );
            if (match != null) targetId = match.id;
          } catch (_) {}
        }
      }

      if (targetId != null) {
        await consultationRemoteDataSource.deleteConsultation(
          consultationId: targetId,
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
        await hiveService.userBox.delete('consultation_$targetId');
      }
      await hiveService.userBox.delete('consultation_$cleanId');
      await hiveService.userBox.delete(consultation.id);
      return true;
    }

    final clientUuid = consultation.clientUuid ??
        (UuidUtils.isValidUuid(cleanId) ? cleanId : UuidUtils.generateV4());
    final effectiveConsultationId =
        UuidUtils.isValidUuid(cleanId) ? cleanId : clientUuid;

    // Resolve doctor and hospital dependencies if provided
    String? resolvedDoctorId = consultation.doctorId != null
        ? IdUtils.unprefix(consultation.doctorId!).trim()
        : null;
    if (resolvedDoctorId != null && !UuidUtils.isValidUuid(resolvedDoctorId)) {
      final mappedDoc = _resolveDoctorUuid(resolvedDoctorId);
      if (mappedDoc != null) {
        resolvedDoctorId = mappedDoc;
      } else if (_isDependencyQueued('doctor', resolvedDoctorId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for doctor dependency ($resolvedDoctorId) to sync.';
        return false;
      } else {
        resolvedDoctorId = null;
      }
    }

    String? resolvedHospitalId = consultation.hospitalId != null
        ? IdUtils.unprefix(consultation.hospitalId!).trim()
        : null;
    if (resolvedHospitalId != null &&
        !UuidUtils.isValidUuid(resolvedHospitalId)) {
      final mappedHosp = _resolveHospitalUuid(resolvedHospitalId);
      if (mappedHosp != null) {
        resolvedHospitalId = mappedHosp;
      } else if (_isDependencyQueued('hospital', resolvedHospitalId)) {
        item.status = 'deferred';
        item.errorMessage =
            'Waiting for hospital dependency ($resolvedHospitalId) to sync.';
        return false;
      } else {
        resolvedHospitalId = null;
      }
    }

    final resolvedConsultation = consultation.copyWith(
      doctorId: resolvedDoctorId,
      hospitalId: resolvedHospitalId,
      clientUuid: clientUuid,
    );

    if (operation == 'create') {
      final remoteList = await consultationRemoteDataSource.fetchConsultations(
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );
      final match = remoteList.firstWhereOrNull(
        (c) =>
            (c.clientUuid != null && c.clientUuid == clientUuid) ||
            c.id == cleanId,
      );

      final isAlreadyCreated = match != null;
      final targetConsultationId =
          isAlreadyCreated ? match.id : effectiveConsultationId;

      if (!isAlreadyCreated) {
        await consultationRemoteDataSource.createConsultation(
          consultation: resolvedConsultation.copyWith(
            id: targetConsultationId,
            attachments: [],
          ),
          ownerUserId: ownerUserId,
          profileId: profileUuid,
        );
      }

      final uploadedAttachments = <ConsultationAttachment>[];
      for (final att in consultation.attachments) {
        if (att.filePath != null &&
            File(att.filePath!).existsSync() &&
            (att.fileUrl == null ||
                att.fileUrl!.isEmpty ||
                att.fileUrl!.startsWith('/') ||
                att.fileUrl!.startsWith('file:') ||
                !att.fileUrl!.contains('/'))) {
          final attUuid = _resolveAttachmentUuid(att.id, att.fileUrl);
          final storagePath = SupabaseStorageService.buildObjectPath(
            userId: ownerUserId,
            parentId: targetConsultationId,
            fileName: att.name,
            attachmentId: attUuid,
          );
          final uploadedPath = await storageService.uploadFile(
            bucket: SupabaseStorageService.consultationsBucket,
            storagePath: storagePath,
            file: File(att.filePath!),
            expectedUserId: ownerUserId,
          );
          uploadedAttachments
              .add(att.copyWith(id: attUuid, fileUrl: uploadedPath));
        } else {
          uploadedAttachments.add(att);
        }
      }

      final remoteConsultation =
          await consultationRemoteDataSource.updateConsultation(
        consultation: resolvedConsultation.copyWith(
          id: targetConsultationId,
          attachments: uploadedAttachments,
        ),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );

      final mergedAttachments = <ConsultationAttachment>[];
      for (final rAtt in remoteConsultation.attachments) {
        final localMatch = consultation.attachments.firstWhereOrNull(
          (lAtt) => lAtt.id == rAtt.id || lAtt.name == rAtt.name,
        );
        mergedAttachments.add(rAtt.copyWith(filePath: localMatch?.filePath));
      }

      final finalConsultation =
          remoteConsultation.copyWith(attachments: mergedAttachments);
      await _reconcileUserBox(
        'consultation_',
        consultation.id,
        finalConsultation.id,
        finalConsultation.toJson(),
      );
      return true;
    }

    if (operation == 'update') {
      final uploadedAttachments = <ConsultationAttachment>[];
      for (final att in consultation.attachments) {
        if (att.filePath != null &&
            File(att.filePath!).existsSync() &&
            (att.fileUrl == null ||
                att.fileUrl!.isEmpty ||
                att.fileUrl!.startsWith('/') ||
                att.fileUrl!.startsWith('file:') ||
                !att.fileUrl!.contains('/'))) {
          final attUuid = _resolveAttachmentUuid(att.id, att.fileUrl);
          final storagePath = SupabaseStorageService.buildObjectPath(
            userId: ownerUserId,
            parentId: cleanId,
            fileName: att.name,
            attachmentId: attUuid,
          );
          final uploadedPath = await storageService.uploadFile(
            bucket: SupabaseStorageService.consultationsBucket,
            storagePath: storagePath,
            file: File(att.filePath!),
            expectedUserId: ownerUserId,
          );
          uploadedAttachments
              .add(att.copyWith(id: attUuid, fileUrl: uploadedPath));
        } else {
          uploadedAttachments.add(att);
        }
      }

      final remoteConsultation =
          await consultationRemoteDataSource.updateConsultation(
        consultation: resolvedConsultation.copyWith(
          id: cleanId,
          attachments: uploadedAttachments,
        ),
        ownerUserId: ownerUserId,
        profileId: profileUuid,
      );

      final mergedAttachments = <ConsultationAttachment>[];
      for (final rAtt in remoteConsultation.attachments) {
        final localMatch = consultation.attachments.firstWhereOrNull(
          (lAtt) => lAtt.id == rAtt.id || lAtt.name == rAtt.name,
        );
        mergedAttachments.add(rAtt.copyWith(filePath: localMatch?.filePath));
      }

      final finalConsultation =
          remoteConsultation.copyWith(attachments: mergedAttachments);
      await _reconcileUserBox(
        'consultation_',
        consultation.id,
        finalConsultation.id,
        finalConsultation.toJson(),
      );
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _reconcileUserBox(
    String prefix,
    String localId,
    String serverId,
    Map<String, dynamic> data,
  ) async {
    final box = hiveService.userBox;
    final cleanLocal = IdUtils.unprefix(localId);
    final cleanServer = IdUtils.unprefix(serverId);

    if (cleanLocal != cleanServer && cleanLocal.isNotEmpty) {
      await box.delete('$prefix$cleanLocal');
      await box.delete(localId);
    }
    await box.put('$prefix$cleanServer', data);
  }
}
