import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/consultation_remote_data_source.dart';
import '../models/consultation_attachment.dart';
import '../models/consultation_model.dart';

/// ConsultationSyncHandler manages payload transformation, API synchronization,
/// binary attachment preparation, 3-tier doctor/hospital ID cascade resolution,
/// local Hive re-keying, and server-assigned ID reconciliation for Consultations.
class ConsultationSyncHandler {
  ConsultationSyncHandler._();

  /// Transforms a local consultation payload into a clean server-compliant JSON map
  /// for Laravel `POST /api/v1/consultations` or `PUT /api/v1/consultations/{id}`.
  ///
  /// Omits device-local `file_path` from standard JSON fields to prevent leaking
  /// local device storage paths to the backend.
  static Map<String, dynamic> toServerMetadataPayload(
    Map<String, dynamic> localPayload,
  ) {
    final rawProfileId =
        localPayload['profile_id'] ?? localPayload['profileId'];
    final cleanProfileId =
        IdUtils.toServerIntId(rawProfileId) ??
        int.tryParse(IdUtils.unprefix(rawProfileId?.toString())) ??
        rawProfileId;

    final rawDoctorId = localPayload['doctor_id'] ?? localPayload['doctorId'];
    final cleanDoctorId = IdUtils.toServerIntId(rawDoctorId);

    final rawHospitalId =
        localPayload['hospital_id'] ?? localPayload['hospitalId'];
    final cleanHospitalId = IdUtils.toServerIntId(rawHospitalId);

    final rawDeptId =
        localPayload['department_id'] ?? localPayload['departmentId'];
    final cleanDeptId = IdUtils.toServerIntId(rawDeptId);

    final rawAptId =
        localPayload['appointment_id'] ?? localPayload['appointmentId'];
    final cleanAptId = IdUtils.toServerIntId(rawAptId);

    final isFollowUpRequired =
        localPayload['is_follow_up_required'] == true ||
        localPayload['isFollowUpRequired'] == true;

    final serverMap = <String, dynamic>{
      'profile_id': cleanProfileId,
      'doctor_name': localPayload['doctor_name'] ?? localPayload['doctorName'],
      'visit_date': localPayload['visit_date'] ?? localPayload['visitDate'],
      'chief_complaint':
          localPayload['chief_complaint'] ?? localPayload['chiefComplaint'],
      'diagnosis': localPayload['diagnosis'],
    };

    if (cleanDoctorId != null) {
      serverMap['doctor_id'] = cleanDoctorId;
    }
    final docSpecialty =
        localPayload['doctor_specialty'] ?? localPayload['doctorSpecialty'];
    if (docSpecialty != null && docSpecialty.toString().trim().isNotEmpty) {
      serverMap['doctor_specialty'] = docSpecialty.toString().trim();
    }
    if (cleanHospitalId != null) {
      serverMap['hospital_id'] = cleanHospitalId;
    }
    final hospName =
        localPayload['hospital_name'] ?? localPayload['hospitalName'];
    if (hospName != null && hospName.toString().trim().isNotEmpty) {
      serverMap['hospital_name'] = hospName.toString().trim();
    }
    if (cleanDeptId != null) {
      serverMap['department_id'] = cleanDeptId;
    }
    final deptName = localPayload['department'];
    if (deptName != null && deptName.toString().trim().isNotEmpty) {
      serverMap['department'] = deptName.toString().trim();
    }
    final vTime = localPayload['visit_time'] ?? localPayload['visitTime'];
    if (vTime != null && vTime.toString().trim().isNotEmpty) {
      serverMap['visit_time'] = vTime.toString().trim();
    }
    final cNotes =
        localPayload['clinical_notes'] ?? localPayload['clinicalNotes'];
    if (cNotes != null && cNotes.toString().trim().isNotEmpty) {
      serverMap['clinical_notes'] = cNotes.toString().trim();
    }
    serverMap['is_follow_up_required'] = isFollowUpRequired;
    if (isFollowUpRequired) {
      final fDate =
          localPayload['follow_up_date'] ?? localPayload['followUpDate'];
      if (fDate != null) {
        serverMap['follow_up_date'] = fDate;
      }
      final fTime =
          localPayload['follow_up_time'] ?? localPayload['followUpTime'];
      if (fTime != null && fTime.toString().trim().isNotEmpty) {
        serverMap['follow_up_time'] = fTime.toString().trim();
      }
      if (localPayload['follow_up_reminder'] != null ||
          localPayload['followUpReminder'] != null) {
        serverMap['follow_up_reminder'] =
            localPayload['follow_up_reminder'] ??
            localPayload['followUpReminder'];
      }
      final fNotes =
          localPayload['follow_up_notes'] ?? localPayload['followUpNotes'];
      if (fNotes != null && fNotes.toString().trim().isNotEmpty) {
        serverMap['follow_up_notes'] = fNotes.toString().trim();
      }
    }
    final rawTags = localPayload['tags'];
    if (rawTags is List && rawTags.isNotEmpty) {
      serverMap['tags'] = rawTags;
    }
    if (localPayload['consultation_fee'] != null ||
        localPayload['consultationFee'] != null) {
      serverMap['consultation_fee'] =
          localPayload['consultation_fee'] ?? localPayload['consultationFee'];
    }
    if (localPayload['currency'] != null) {
      serverMap['currency'] = localPayload['currency'];
    }
    if (cleanAptId != null) {
      serverMap['appointment_id'] = cleanAptId;
    }
    final cUuid = localPayload['client_uuid'] ?? localPayload['clientUuid'];
    if (cUuid != null && cUuid.toString().trim().isNotEmpty) {
      serverMap['client_uuid'] = cUuid.toString().trim();
    }

    return serverMap;
  }

  /// Extracts attachment models from a local consultation payload.
  static List<ConsultationAttachment> extractAttachments(
    Map<String, dynamic> localPayload,
  ) {
    final rawAttachments = localPayload['attachments'];
    if (rawAttachments is List) {
      return rawAttachments
          .whereType<Map>()
          .map(
            (m) =>
                ConsultationAttachment.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    }
    return const [];
  }

  /// Synchronizes binary attachments to the backend.
  ///
  /// =========================================================================
  /// ATTACHMENT UPLOAD PIPELINE — PENDING BACKEND API SUPPORT
  /// =========================================================================
  /// The current Laravel API specification supports binary multipart uploads
  /// exclusively for Reports (`R2: POST /api/v1/reports`). Consultation attachment
  /// upload endpoints (e.g. `POST /api/v1/consultations/{id}/attachments` or
  /// multipart `POST /api/v1/consultations`) have not yet been deployed on Laravel.
  ///
  /// WHEN BACKEND API IS AVAILABLE:
  /// 1. Iterate over [attachments] that have valid local `filePath`.
  /// 2. Stream binary bytes via `multipart/form-data` using ApiClient.
  /// 3. Update the local ConsultationAttachment with the server-assigned URL/ID.
  ///
  /// FOR NOW:
  /// - Attachments remain securely persisted in local Hive storage.
  /// - Local file paths are preserved intact for device access and future sync.
  /// - This method gracefully returns `true` to keep the sync queue moving.
  /// =========================================================================
  static Future<bool> syncAttachments({
    required String consultationId,
    required List<ConsultationAttachment> attachments,
  }) async {
    if (attachments.isEmpty) {
      return true;
    }

    return true;
  }

  /// Handles synchronization of a single consultation mutation with the remote API,
  /// updates local Hive storage upon successful response, reconciles server IDs,
  /// resolves doctor and hospital foreign keys via 3-tier cascade, and triggers
  /// attachment synchronization.
  static Future<bool> process({
    required SyncQueueItem item,
    required ConsultationRemoteDataSource remoteDataSource,
    required Box userBox,
    required Box profileBox,
    int? Function(String prefix, Map<String, dynamic> payload)?
    resolveDeleteServerId,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(item.payload);
      final operation = item.operation.toLowerCase();
      final localId = payload['id']?.toString() ?? item.id;
      final cleanId = IdUtils.unprefix(localId);
      final serverIntId = IdUtils.toServerIntId(cleanId);
      final isServerNumericId = serverIntId != null;

      // Handle DELETE operation
      if (operation == 'delete') {
        final serverId = isServerNumericId
            ? serverIntId
            : (resolveDeleteServerId != null
                ? resolveDeleteServerId('consultation_', payload)
                : _resolveDeleteServerIdFallback('consultation_', payload, userBox));
        if (serverId != null) {
          await remoteDataSource.deleteConsultation(serverId);
        } else if (payload['_needs_server_id'] == true) {
          item.status = 'deferred';
          return false;
        }
        await userBox.delete('consultation_$cleanId');
        await userBox.delete(localId);
        return true;
      }

      // Resolve Profile Server ID from Hive
      var rawProfileId = payload['profile_id'] ?? payload['profileId'];
      if (rawProfileId == null) {
        final existing =
            userBox.get(localId) ?? userBox.get('consultation_$cleanId');
        if (existing is Map) {
          rawProfileId = existing['profile_id'] ?? existing['profileId'];
        }
      }
      final cleanProfileId = IdUtils.resolveServerProfileId(
        profileBox: profileBox,
        profileId: rawProfileId?.toString(),
      );
      if (cleanProfileId == null) {
        debugPrint(
          '[ConsultationSyncHandler] Cannot sync Consultation: profile_id ($rawProfileId) not resolved to server ID yet. Deferring sync.',
        );
        // Dependency not ready -> defer without consuming the retry budget (F2).
        item.status = 'deferred';
        return false;
      }
      payload['profile_id'] = cleanProfileId;

      // 1. Resolve Doctor / Hospital Server IDs from Hive if dependencies synced earlier
      final rawDoctorId = payload['doctor_id'] ?? payload['doctorId'];
      if (rawDoctorId != null) {
        var resolvedDocId = IdUtils.toServerIntId(rawDoctorId);
        if (resolvedDocId == null) {
          final docKey = 'doctor_${IdUtils.unprefix(rawDoctorId.toString())}';
          final docData =
              userBox.get(docKey) ?? userBox.get(rawDoctorId.toString());
          if (docData is Map) {
            resolvedDocId = IdUtils.toServerIntId(docData['id']);
          }
        }

        // If still null, check by doctor_name across userBox
        if (resolvedDocId == null && payload['doctor_name'] != null) {
          final targetName = payload['doctor_name']
              .toString()
              .trim()
              .toLowerCase();
          for (final entry in userBox.toMap().entries) {
            if (entry.key.toString().startsWith('doctor_')) {
              final d = entry.value;
              if (d is Map &&
                  d['name']?.toString().trim().toLowerCase() == targetName) {
                resolvedDocId = IdUtils.toServerIntId(d['id']);
                if (resolvedDocId != null) break;
              }
            }
          }
        }

        if (resolvedDocId != null) {
          payload['doctor_id'] = resolvedDocId;
        } else {
          payload.remove('doctor_id');
        }
      }

      final rawHospitalId = payload['hospital_id'] ?? payload['hospitalId'];
      if (rawHospitalId != null) {
        var resolvedHospId = IdUtils.toServerIntId(rawHospitalId);
        if (resolvedHospId == null) {
          final hospKey =
              'hospital_${IdUtils.unprefix(rawHospitalId.toString())}';
          final hospData =
              userBox.get(hospKey) ?? userBox.get(rawHospitalId.toString());
          if (hospData is Map) {
            resolvedHospId = IdUtils.toServerIntId(hospData['id']);
          }
        }

        // If still null, check by hospital_name across userBox
        if (resolvedHospId == null && payload['hospital_name'] != null) {
          final targetName = payload['hospital_name']
              .toString()
              .trim()
              .toLowerCase();
          for (final entry in userBox.toMap().entries) {
            if (entry.key.toString().startsWith('hospital_')) {
              final h = entry.value;
              if (h is Map &&
                  h['name']?.toString().trim().toLowerCase() == targetName) {
                resolvedHospId = IdUtils.toServerIntId(h['id']);
                if (resolvedHospId != null) break;
              }
            }
          }
        }

        if (resolvedHospId != null) {
          payload['hospital_id'] = resolvedHospId;
        } else {
          payload.remove('hospital_id');
        }
      }

      // 2. Build clean, server-compliant metadata payload
      final serverMetadata = toServerMetadataPayload(payload);

      // 3. Dispatch HTTP request
      Map<String, dynamic> responseData;

      if (operation == 'update' && isServerNumericId) {
        responseData = await remoteDataSource.updateConsultation(
          serverIntId,
          serverMetadata,
        );
      } else {
        final attachments = extractAttachments(payload);
        responseData = await remoteDataSource.addConsultation(
          serverMetadata,
          attachments: attachments,
        );
      }

      // 4. Update local Hive consultation with server-assigned ID & preserve client_uuid
      final serverId = responseData['id']?.toString() ?? '';
      if (serverId.isNotEmpty) {
        final localId = payload['id']?.toString() ?? '';
        final oldKey = 'consultation_${IdUtils.unprefix(localId)}';

        final localRaw = userBox.get(oldKey) ?? userBox.get(localId);
        ConsultationModel? localModel;
        if (localRaw is Map) {
          localModel = ConsultationModel.fromJson(
            Map<String, dynamic>.from(localRaw),
          );
        }

        final serverModel = ConsultationModel.fromJson(responseData);
        final clientUuid =
            payload['client_uuid']?.toString() ??
            payload['clientUuid']?.toString() ??
            localModel?.clientUuid ??
            serverModel.clientUuid;

        final synchronized = serverModel.copyWith(
          id: 'consultation_$serverId',
          profileId:
              localModel?.profileId ??
              payload['profile_id']?.toString() ??
              serverModel.profileId,
          clientUuid: clientUuid,
          attachments: (localModel != null && localModel.attachments.isNotEmpty)
              ? localModel.attachments
              : serverModel.attachments,
        );

        if (oldKey != 'consultation_$serverId') {
          await userBox.delete(oldKey);
          await userBox.delete(localId);
        }
        await userBox.put('consultation_$serverId', synchronized.toJson());

        // 5. Trigger attachment sync if attachments are present
        final attachments = extractAttachments(payload);
        if (attachments.isNotEmpty) {
          await syncAttachments(
            consultationId: serverId,
            attachments: attachments,
          );
        }
      }

      return true;
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      debugPrint(
        '[ConsultationSyncHandler] Consultation sync DioException: HTTP $statusCode - ${dioErr.message}',
      );

      // Classify error:
      // 400, 404, 422 are permanent client/validation errors (dead-letter)
      if (statusCode != null &&
          (statusCode == 400 || statusCode == 404 || statusCode == 422)) {
        item.status = 'failed';
        item.retryCount = 99; // Mark dead-letter; do not retry automatically
        item.errorMessage =
            'Validation/Client error ($statusCode): ${dioErr.response?.data}';
      } else if (statusCode == 401) {
        // 401 Unauthorized: Recoverable authentication failure
        item.status = 'auth_required';
        item.errorMessage =
            'Authentication required ($statusCode): Session unauthenticated';
      } else if (statusCode == 403) {
        // 403 Forbidden: Authorization issue
        item.status = 'failed';
        item.errorMessage = 'Forbidden ($statusCode): ${dioErr.response?.data}';
      } else {
        item.errorMessage = 'Network error ($statusCode): ${dioErr.message}';
      }
      return false;
    } catch (err) {
      debugPrint(
        '[ConsultationSyncHandler] Error processing consultation sync: $err',
      );
      item.errorMessage = err.toString();
      return false;
    }
  }

  /// Fallback resolver for delete server ID if not provided by caller.
  static int? _resolveDeleteServerIdFallback(
    String prefix,
    Map<String, dynamic> payload,
    Box userBox,
  ) {
    final direct = IdUtils.toServerIntId(payload['id']);
    if (direct != null) return direct;
    final uuid = (payload['client_uuid'] ?? payload['clientUuid'])
        ?.toString()
        .trim();
    if (uuid == null || uuid.isEmpty) return null;
    for (final key in userBox.keys) {
      if (!key.toString().startsWith(prefix)) continue;
      final raw = userBox.get(key);
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final cu = (m['client_uuid'] ?? m['clientUuid'])?.toString().trim();
      if (cu != uuid) continue;
      return IdUtils.toServerIntId(m['id']) ??
          IdUtils.toServerIntId(key.toString());
    }
    return null;
  }
}
