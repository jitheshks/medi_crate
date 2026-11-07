import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/report_remote_data_source.dart';
import '../models/report_model.dart';

/// ReportSyncHandler manages the separation between Report metadata
/// synchronization and binary multipart attachment synchronization for Laravel API (R1 - R6).
class ReportSyncHandler {
  ReportSyncHandler._();

  /// Transforms a local report payload into a clean server-compliant JSON metadata map.
  ///
  /// OMITs device-local `file_path` from standard JSON fields to prevent leaking
  /// local device storage paths to the backend and to prepare for the multipart boundary.
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

    final rawConsultationId =
        localPayload['consultation_id'] ?? localPayload['consultationId'];
    final cleanConsultationId = IdUtils.toServerIntId(rawConsultationId);

    final rawCategory =
        localPayload['category']?.toString() ??
        localPayload['report_type']?.toString() ??
        'LAB TEST';
    final normalizedCategory = ReportModel.normalizeCategoryToApi(rawCategory);

    final serverMap = <String, dynamic>{
      'profile_id': cleanProfileId,
      'title': localPayload['title'] ?? '',
      'category': normalizedCategory,
      'date':
          (localPayload['date']?.toString() ?? DateTime.now().toIso8601String())
              .split('T')
              .first,
    };

    if (cleanDoctorId != null) {
      serverMap['doctor_id'] = cleanDoctorId;
    }
    final docName = localPayload['doctor_name'] ?? localPayload['doctor'];
    if (docName != null && docName.toString().trim().isNotEmpty) {
      serverMap['doctor_name'] = docName.toString().trim();
    }

    if (cleanHospitalId != null) {
      serverMap['hospital_id'] = cleanHospitalId;
    }
    final hospName = localPayload['hospital_name'] ?? localPayload['hospital'];
    if (hospName != null && hospName.toString().trim().isNotEmpty) {
      serverMap['hospital_name'] = hospName.toString().trim();
    }

    if (cleanConsultationId != null) {
      serverMap['consultation_id'] = cleanConsultationId;
    }
    final consultTitle =
        localPayload['consultation_title'] ?? localPayload['consultationTitle'];
    if (consultTitle != null && consultTitle.toString().trim().isNotEmpty) {
      serverMap['consultation_title'] = consultTitle.toString().trim();
    }

    final notes = localPayload['notes'];
    if (notes != null && notes.toString().trim().isNotEmpty) {
      serverMap['notes'] = notes.toString().trim();
    }

    // Expense parsing
    if (localPayload['expense'] is Map) {
      final exp = Map<String, dynamic>.from(localPayload['expense'] as Map);
      if (exp['amount'] != null) {
        serverMap['expense_amount'] = (exp['amount'] as num).toDouble();
      }
      if (exp['status'] != null) {
        serverMap['expense_status'] = exp['status'].toString().toLowerCase();
      }
      if (exp['currency'] != null) {
        serverMap['expense_currency'] = exp['currency'].toString();
      }
    } else {
      if (localPayload['expense_amount'] != null) {
        serverMap['expense_amount'] = (localPayload['expense_amount'] as num)
            .toDouble();
      }
      if (localPayload['expense_status'] != null) {
        serverMap['expense_status'] = localPayload['expense_status']
            .toString()
            .toLowerCase();
      }
      if (localPayload['expense_currency'] != null) {
        serverMap['expense_currency'] = localPayload['expense_currency']
            .toString();
      }
    }

    final cUuid = localPayload['client_uuid'] ?? localPayload['clientUuid'];
    if (cUuid != null && cUuid.toString().trim().isNotEmpty) {
      serverMap['client_uuid'] = cUuid.toString().trim();
    }

    return serverMap;
  }

  /// Extracts typed [ReportAttachmentModel] instances from a local report payload.
  static List<ReportAttachmentModel> extractAttachments(
    Map<String, dynamic> localPayload,
  ) {
    final rawAttachments = localPayload['attachments'];
    if (rawAttachments is List) {
      return rawAttachments
          .whereType<Map>()
          .map(
            (m) => ReportAttachmentModel.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    }
    return const [];
  }

  /// Validates that all persistent local attachment files exist on disk before sync.
  /// Returns a map of attachment IDs to existence status.
  static Map<String, bool> validateAttachmentFiles(
    List<ReportAttachmentModel> attachments,
  ) {
    final result = <String, bool>{};
    for (final att in attachments) {
      if (att.filePath != null && att.filePath!.trim().isNotEmpty) {
        final file = File(att.filePath!);
        result[att.id] = file.existsSync();
      } else {
        result[att.id] = false;
      }
    }
    return result;
  }

  /// Returns true if all local attachments for this report are present on disk.
  static bool areAllAttachmentsPresent(
    List<ReportAttachmentModel> attachments,
  ) {
    if (attachments.isEmpty) return true;
    for (final att in attachments) {
      if (att.filePath != null && att.filePath!.trim().isNotEmpty) {
        final file = File(att.filePath!);
        if (!file.existsSync()) {
          return false;
        }
      }
    }
    return true;
  }

  /// Synchronizes binary attachments to the backend.
  ///
  /// =========================================================================
  /// MULTIPART ATTACHMENT UPLOAD PIPELINE — PHASE 2 PREPARATION
  /// =========================================================================
  /// The backend API specification (`R2: POST /api/v1/reports`) accepts binary
  /// multipart file uploads in `files[]`.
  ///
  /// IN PHASE 2:
  /// 1. `ReportRemoteDataSource.uploadReport(metadata, attachments)` will construct
  ///    `FormData` with `MultipartFile.fromFile(filePath)`.
  /// 2. The server response returns `attachments: [{id, name, size, file_url, file_type}]`.
  /// 3. The local Hive Report is updated with server attachment IDs and file URLs
  ///    while retaining the persistent local `filePath` for instant local caching.
  ///
  /// IN PHASE 1:
  /// - Attachments are safely stored in persistent local directories.
  /// - Local file paths and metadata are preserved in SyncQueue payloads.
  /// - Returns `true` to validate architecture without executing multipart POST.
  /// =========================================================================
  static Future<bool> syncAttachments({
    required String reportId,
    required List<ReportAttachmentModel> attachments,
  }) async {
    if (attachments.isEmpty) {
      return true;
    }
    return true;
  }

  /// Handles synchronization of a single report mutation with the remote API,
  /// validates physical attachment files on disk, updates local Hive storage upon successful
  /// response, reconciles server IDs while preserving local file paths and client_uuid,
  /// and resolves doctor, hospital, and consultation foreign keys.
  static Future<bool> process({
    required SyncQueueItem item,
    required ReportRemoteDataSource remoteDataSource,
    required Box userBox,
    required Box profileBox,
    int? Function(String prefix, Map<String, dynamic> payload)?
    resolveDeleteServerId,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(item.payload);
      final operation = item.operation.toLowerCase();

      // Handle DELETE operation
      if (operation == 'delete') {
        final serverIntId =
            IdUtils.toServerIntId(payload['id']) ??
            (resolveDeleteServerId != null
                ? resolveDeleteServerId('report_', payload)
                : _resolveDeleteServerIdFallback('report_', payload, userBox));
        if (serverIntId != null) {
          await remoteDataSource.deleteReport(serverIntId);
        } else if (payload['_needs_server_id'] == true) {
          item.status = 'deferred';
          return false;
        }
        return true;
      }

      // Resolve Profile Server ID from Hive
      var rawProfileId = payload['profile_id'] ?? payload['profileId'];
      if (rawProfileId == null) {
        final existing =
            userBox.get(payload['id']) ??
            userBox.get(
              'report_${IdUtils.unprefix(payload['id']?.toString())}',
            );
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
          '[ReportSyncHandler] Cannot sync Report: profile_id ($rawProfileId) not resolved to server ID yet. Deferring sync.',
        );
        // Dependency not ready -> defer without consuming the retry budget (F2).
        item.status = 'deferred';
        return false;
      }
      payload['profile_id'] = cleanProfileId;

      // 1. Resolve Doctor / Hospital / Consultation Server IDs from Hive if dependencies synced earlier
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
        if (resolvedHospId != null) {
          payload['hospital_id'] = resolvedHospId;
        } else {
          payload.remove('hospital_id');
        }
      }

      final rawConsultId =
          payload['consultation_id'] ?? payload['consultationId'];
      if (rawConsultId != null) {
        var resolvedConsultId = IdUtils.toServerIntId(rawConsultId);
        if (resolvedConsultId == null) {
          final consultKey =
              'consultation_${IdUtils.unprefix(rawConsultId.toString())}';
          final consultData =
              userBox.get(consultKey) ?? userBox.get(rawConsultId.toString());
          if (consultData is Map) {
            resolvedConsultId = IdUtils.toServerIntId(consultData['id']);
          }
        }
        if (resolvedConsultId != null) {
          payload['consultation_id'] = resolvedConsultId;
        } else {
          payload.remove('consultation_id');
        }
      }

      // 2. Validate local physical attachment files on disk
      final localAttachments = extractAttachments(payload);
      final fileStatusMap = validateAttachmentFiles(localAttachments);
      for (final entry in fileStatusMap.entries) {
        if (!entry.value) {
          debugPrint(
            '[ReportSyncHandler] Warning: Local attachment file for ${entry.key} is missing on disk.',
          );
        }
      }

      // 3. Build clean, server-compliant metadata payload
      final serverMetadata = toServerMetadataPayload(payload);

      // 4. Dispatch HTTP request
      Map<String, dynamic> responseData;

      final localId = payload['id']?.toString() ?? '';
      final cleanId = IdUtils.unprefix(localId);
      final serverIntId = IdUtils.toServerIntId(cleanId);
      final isServerNumericId = serverIntId != null;

      if (operation == 'update' && isServerNumericId) {
        responseData = await remoteDataSource.updateReport(
          serverIntId,
          serverMetadata,
        );
      } else {
        responseData = await remoteDataSource.addReport(
          serverMetadata,
          attachments: localAttachments,
        );
      }

      // 5. Update local Hive report with server-assigned ID & preserve client_uuid & local file paths
      final serverId = responseData['id']?.toString() ?? '';
      if (serverId.isNotEmpty) {
        final localId = payload['id']?.toString() ?? '';
        final oldKey = 'report_${IdUtils.unprefix(localId)}';

        final localRaw = userBox.get(oldKey) ?? userBox.get(localId);
        ReportModel? localModel;
        if (localRaw is Map) {
          localModel = ReportModel.fromJson(
            Map<String, dynamic>.from(localRaw),
          );
        }

        final serverModel = ReportModel.fromJson(responseData);
        final clientUuid =
            payload['client_uuid']?.toString() ??
            payload['clientUuid']?.toString() ??
            localModel?.clientUuid ??
            serverModel.clientUuid;

        // Merge attachments: retain local filePath while updating server attachment ID and file_url
        List<ReportAttachmentModel> mergedAttachments = [];
        if (localModel != null && localModel.attachments.isNotEmpty) {
          final serverAttachments = serverModel.attachments;
          for (final localAtt in localModel.attachments) {
            final serverMatch = serverAttachments.where((s) {
              if (s.id.isNotEmpty &&
                  localAtt.id.isNotEmpty &&
                  s.id == localAtt.id) {
                return true;
              }
              if (s.name.isNotEmpty &&
                  localAtt.name.isNotEmpty &&
                  s.name == localAtt.name) {
                return true;
              }
              return false;
            }).firstOrNull;

            if (serverMatch != null) {
              mergedAttachments.add(
                localAtt.copyWith(
                  id: serverMatch.id.isNotEmpty ? serverMatch.id : localAtt.id,
                  fileUrl: serverMatch.fileUrl ?? localAtt.fileUrl,
                  sizeBytes: serverMatch.sizeBytes ?? localAtt.sizeBytes,
                  fileType: serverMatch.fileType ?? localAtt.fileType,
                ),
              );
            } else {
              mergedAttachments.add(localAtt);
            }
          }

          // Add any server attachments that were not present locally
          for (final sAtt in serverAttachments) {
            final alreadyMerged = mergedAttachments.any(
              (m) =>
                  (m.id.isNotEmpty && m.id == sAtt.id) ||
                  (m.name.isNotEmpty && m.name == sAtt.name),
            );
            if (!alreadyMerged) {
              mergedAttachments.add(sAtt);
            }
          }
        } else {
          mergedAttachments = serverModel.attachments;
        }

        final synchronized = serverModel.copyWith(
          id: 'report_$serverId',
          profileId:
              localModel?.profileId ??
              payload['profile_id']?.toString() ??
              serverModel.profileId,
          clientUuid: clientUuid,
          attachments: mergedAttachments,
        );

        if (oldKey != 'report_$serverId') {
          await userBox.delete(oldKey);
          await userBox.delete(localId);
        }
        await userBox.put('report_$serverId', synchronized.toJson());

        // 6. Trigger attachment sync hook
        if (mergedAttachments.isNotEmpty) {
          await syncAttachments(
            reportId: serverId,
            attachments: mergedAttachments,
          );
        }
      }

      return true;
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      debugPrint(
        '[ReportSyncHandler] Report sync DioException: HTTP $statusCode - ${dioErr.message}',
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
      debugPrint('[ReportSyncHandler] Error processing report sync: $err');
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
