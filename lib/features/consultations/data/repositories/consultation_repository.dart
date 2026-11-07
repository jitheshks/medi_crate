import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../../../core/api/list_pull_support.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/storage/attachment_cleanup_helper.dart';
import '../../../../core/storage/hive_profile_query_helper.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../doctors/data/models/doctor_hospital_relation.dart';
import '../datasources/remote/consultation_remote_data_source.dart';
import '../models/consultation_attachment.dart';
import '../models/consultation_model.dart';

/// ConsultationRepository manages profile-scoped consultation records with offline-first synchronization.
class ConsultationRepository {
  final HiveService hiveService;
  final SyncService? syncService;
  final ConsultationRemoteDataSource? remoteDataSource;
  final ConnectivityService? connectivityService;

  /// Post-pull freshness signal (Phase 3): invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  /// Whether the last completed pull retrieved the full server dataset
  /// (`received >= data.total`). Exposed for tests.
  bool lastPullComplete = true;

  ConsultationRepository({
    required this.hiveService,
    this.syncService,
    this.remoteDataSource,
    this.connectivityService,
    this.onPullMerged,
  });

  String _normalizeId(String rawId) {
    if (rawId.startsWith('consultation_')) return rawId;
    return 'consultation_$rawId';
  }

  /// Fetches raw maps for consultations for active [profileId].
  Future<List<Map<String, dynamic>>> getConsultations(String profileId) async {
    return HiveProfileQueryHelper.getRecordsForProfile(
      userBox: hiveService.userBox,
      profileBox: hiveService.profileBox,
      keyPrefix: 'consultation_',
      profileId: profileId,
    );
  }

  /// Fetches consultation models for active [profileId] immediately from local Hive cache,
  /// and dispatches a non-blocking background pull-sync when online.
  Future<List<ConsultationModel>> getConsultationModels(
    String profileId,
  ) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (remoteDataSource != null) {
      unawaited(pullConsultations(profileId));
    }

    // 2. Return local records immediately
    final rawList = await getConsultations(profileId);
    final list = rawList.map((map) => ConsultationModel.fromJson(map)).toList();
    list.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return list;
  }

  /// Performs background pull-sync for consultations belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullConsultations(String profileId) {
    if (remoteDataSource == null) return Future.value();
    final existing = _inFlightPulls[profileId];
    if (existing != null) return existing;

    final future = _executePullConsultations(profileId);
    _inFlightPulls[profileId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[profileId], future)) {
        _inFlightPulls.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _executePullConsultations(String profileId) async {
    try {
      final numericProfileId = IdUtils.resolveServerProfileId(
        profileBox: hiveService.profileBox,
        profileId: profileId,
      );
      if (numericProfileId == null) return;

      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;

      if (!isOnline) return;

      final remoteList = await fetchCompleteList(
        (limit, onTotal) => remoteDataSource!.fetchConsultations(
          profileId: numericProfileId,
          limit: limit,
          onTotal: onTotal,
        ),
        onComplete: (c) => lastPullComplete = c,
      );
      if (remoteList.isNotEmpty) {
        final box = hiveService.userBox;
        var pulledChanged = false;
        for (final map in remoteList) {
          final model = ConsultationModel.fromJson(map);
          final key = _normalizeId(model.id);

          // Guard against overwriting pending local mutations (I2-C2)
          if (PendingMutationGuard.hasPendingMutation(
            syncQueueBox: hiveService.syncQueueBox,
            profileBox: hiveService.profileBox,
            entity: 'consultation',
            profileId: profileId,
            remoteId: key,
            clientUuid: model.clientUuid,
          )) {
            continue;
          }

          // Merge: preserve local clientUuid and local attachment filePaths if existing
          final existingRaw = box.get(key) ?? box.get(model.id);
          String? existingUuid;
          List<ConsultationAttachment>? mergedAttachments;
          if (existingRaw is Map) {
            existingUuid =
                existingRaw['client_uuid']?.toString() ??
                existingRaw['clientUuid']?.toString();

            if (existingRaw['attachments'] is List) {
              final localAtts = (existingRaw['attachments'] as List)
                  .whereType<Map>()
                  .map(
                    (m) => ConsultationAttachment.fromJson(
                      Map<String, dynamic>.from(m),
                    ),
                  )
                  .toList();
              if (model.attachments.isEmpty) {
                mergedAttachments = localAtts;
              } else {
                final attList = <ConsultationAttachment>[];
                for (final rAtt in model.attachments) {
                  final localMatch = localAtts
                      .where(
                        (l) =>
                            (l.id.isNotEmpty && l.id == rAtt.id) ||
                            (l.name.isNotEmpty &&
                                l.name == rAtt.name &&
                                l.filePath != null),
                      )
                      .firstOrNull;
                  if (localMatch?.filePath != null &&
                      localMatch!.filePath!.isNotEmpty) {
                    attList.add(rAtt.copyWith(filePath: localMatch.filePath));
                  } else {
                    attList.add(rAtt);
                  }
                }
                mergedAttachments = attList.isNotEmpty ? attList : localAtts;
              }
            }
          }

          final merged = model.copyWith(
            profileId: profileId,
            clientUuid: existingUuid ?? model.clientUuid,
            attachments: mergedAttachments ?? model.attachments,
          );
          final encoded = merged.toJson();
          if (pulledRecordChanged(box.get(key), encoded)) pulledChanged = true;
          await box.put(key, encoded);
        }

        if (pulledChanged) {
          try {
            onPullMerged?.call();
          } catch (_) {}
        }
      }
    } catch (_) {
      // Fallback to local cache on network or parsing failure
    } finally {
      _inFlightPulls.remove(profileId);
    }
  }

  Future<ConsultationModel?> getConsultationById(
    String profileId,
    String consultationId,
  ) async {
    final cleanTarget = IdUtils.unprefix(consultationId);
    final key = _normalizeId(consultationId);
    final box = hiveService.userBox;
    var val = box.get(key) ?? box.get(consultationId) ?? box.get(cleanTarget);
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final storedProfId = (map['profile_id'] ?? map['profileId'])?.toString();
      if (IdUtils.matchesProfileId(
        storedProfId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        return ConsultationModel.fromJson(map);
      }
    }

    if (connectivityService != null && remoteDataSource != null) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          final cleanId = IdUtils.unprefix(consultationId);
          final remoteMap = await remoteDataSource!.getConsultation(cleanId);
          if (remoteMap.isNotEmpty) {
            final model = ConsultationModel.fromJson(remoteMap);
            final key = _normalizeId(model.id);

            // Guard against overwriting pending local mutations (I2-C2)
            if (!PendingMutationGuard.hasPendingMutation(
              syncQueueBox: hiveService.syncQueueBox,
              profileBox: hiveService.profileBox,
              entity: 'consultation',
              profileId: profileId,
              remoteId: key,
              clientUuid: model.clientUuid,
            )) {
              await box.put(key, model.toJson());
              return model;
            }
          }
        } catch (_) {}
      }
    }

    // Comprehensive local scan by IdUtils.matches and client_uuid
    for (final k in box.keys) {
      if (k.toString().startsWith('consultation_')) {
        final entry = box.get(k);
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final storedProfId = (map['profile_id'] ?? map['profileId'])
              ?.toString();
          if (IdUtils.matchesProfileId(
            storedProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final entryId = map['id']?.toString() ?? '';
            final clientUuid =
                map['client_uuid']?.toString() ??
                map['clientUuid']?.toString() ??
                '';
            if (IdUtils.matches(entryId, consultationId) ||
                entryId == key ||
                (clientUuid.isNotEmpty && clientUuid == consultationId)) {
              return ConsultationModel.fromJson(map);
            }
          }
        }
      }
    }

    return null;
  }

  /// Saves a raw consultation payload for [profileId] into Hive and Sync Queue.
  Future<Map<String, dynamic>> saveConsultation(
    String profileId,
    Map<String, dynamic> data,
  ) async {
    final rawId = data['id']?.toString() ?? '';
    final id = rawId.isEmpty
        ? 'consultation_${DateTime.now().microsecondsSinceEpoch}'
        : _normalizeId(rawId);

    final box = hiveService.userBox;
    final isNew =
        rawId.isEmpty || (!box.containsKey(id) && !box.containsKey(rawId));

    final payload = Map<String, dynamic>.from(data);
    payload['id'] = id;
    payload['profile_id'] = profileId;

    // Check if existing record has a client_uuid to preserve during updates
    final existingRaw = box.get(id) ?? box.get(rawId);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    // Preserve existing UUID or generate exactly once for new records
    final clientUuid =
        payload['client_uuid']?.toString() ??
        payload['clientUuid']?.toString() ??
        existingUuid ??
        (isNew ? UuidUtils.generateV4() : null);

    if (clientUuid != null && clientUuid.isNotEmpty) {
      payload['client_uuid'] = clientUuid;
    }

    if (payload['created_at'] == null) {
      payload['created_at'] = DateTime.now().toIso8601String();
    }

    await box.put(id, payload);

    await syncService?.addToQueue(
      SyncQueueItem(
        id: 'sync_consultation_${DateTime.now().microsecondsSinceEpoch}',
        entity: 'consultations',
        operation: isNew ? 'create' : 'update',
        payload: payload,
      ),
    );

    return payload;
  }

  /// Saves a typed [ConsultationModel] for [profileId] and synchronizes with remote API when online.
  Future<ConsultationModel> saveConsultationModel(
    String profileId,
    ConsultationModel consultation,
  ) async {
    final rawId = consultation.id;
    final id = rawId.isNotEmpty
        ? _normalizeId(rawId)
        : 'consultation_${DateTime.now().microsecondsSinceEpoch}';

    final box = hiveService.userBox;
    final isNew =
        rawId.isEmpty || (!box.containsKey(id) && !box.containsKey(rawId));

    // Look up existing record to preserve its UUID if not present in the model
    final existingRaw = box.get(id) ?? box.get(rawId);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    final clientUuid =
        (consultation.clientUuid != null &&
            consultation.clientUuid!.trim().isNotEmpty)
        ? consultation.clientUuid!.trim()
        : (existingUuid ?? (isNew ? UuidUtils.generateV4() : null));

    final updated = consultation.copyWith(
      id: id,
      profileId: profileId,
      clientUuid: clientUuid,
    );
    final payload = updated.toJson();
    await box.put(id, payload);

    // Clean up any removed attachments from disk if updating an existing consultation
    if (existingRaw is Map) {
      try {
        final oldModel = ConsultationModel.fromJson(
          Map<String, dynamic>.from(existingRaw),
        );
        final newFilePaths = updated.attachments
            .map((a) => a.filePath)
            .whereType<String>()
            .toSet();
        final removedPaths = oldModel.attachments
            .map((a) => a.filePath)
            .whereType<String>()
            .where((path) => !newFilePaths.contains(path))
            .toList();
        if (removedPaths.isNotEmpty) {
          await AttachmentCleanupHelper.safelyDeleteFiles(
            hiveService: hiveService,
            filePaths: removedPaths,
            exemptRecordId: id,
          );
        }
      } catch (_) {}
    }

    final isNumericServerId =
        IdUtils.toServerIntId(IdUtils.unprefix(id)) != null;

    if (connectivityService != null && remoteDataSource != null) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        final serverProfileId = IdUtils.resolveServerProfileId(
          profileBox: hiveService.profileBox,
          profileId: profileId,
        );
        if (serverProfileId != null) {
          try {
            Map<String, dynamic> remoteResponse;
            if (isNumericServerId) {
              final cleanId = IdUtils.unprefix(updated.id);
              remoteResponse = await remoteDataSource!.updateConsultation(
                cleanId,
                updated.toApiJson(serverProfileId: serverProfileId),
              );
            } else {
              remoteResponse = await remoteDataSource!.addConsultation(
                updated.toApiJson(serverProfileId: serverProfileId),
                attachments: updated.attachments,
              );
            }
            return await synchronizeConsultationRecord(updated, remoteResponse);
          } catch (_) {
            // On transient/network/server error, queue for offline sync
            await syncService?.addToQueue(
              SyncQueueItem(
                id: 'sync_consultation_${DateTime.now().microsecondsSinceEpoch}',
                entity: 'consultations',
                operation: isNumericServerId ? 'update' : 'create',
                payload: payload,
              ),
            );
            return updated;
          }
        }
      }
    }

    // Queue for offline sync when disconnected or profile server ID not yet resolved
    await syncService?.addToQueue(
      SyncQueueItem(
        id: 'sync_consultation_${DateTime.now().microsecondsSinceEpoch}',
        entity: 'consultations',
        operation: isNumericServerId ? 'update' : 'create',
        payload: payload,
      ),
    );

    return updated;
  }

  /// Associates a server-returned consultation with the local Hive record.
  Future<ConsultationModel> synchronizeConsultationRecord(
    ConsultationModel localConsultation,
    Map<String, dynamic> serverResponse,
  ) async {
    final serverId = serverResponse['id']?.toString() ?? '';
    final serverConsultation = ConsultationModel.fromJson(serverResponse);

    // Preserve local clientUuid and profileId
    final clientUuid =
        (localConsultation.clientUuid != null &&
            localConsultation.clientUuid!.isNotEmpty)
        ? localConsultation.clientUuid
        : serverConsultation.clientUuid;

    final synchronized = serverConsultation.copyWith(
      id: serverId.isNotEmpty ? serverId : localConsultation.id,
      profileId: localConsultation.profileId,
      clientUuid: clientUuid,
      attachments: localConsultation.attachments.isNotEmpty
          ? localConsultation.attachments
          : serverConsultation.attachments,
    );

    final box = hiveService.userBox;
    // If backend assigned a new server ID, remove the temporary local ID entry
    if (serverId.isNotEmpty && serverId != localConsultation.id) {
      final oldKey = _normalizeId(localConsultation.id);
      await box.delete(oldKey);
      await box.delete(localConsultation.id);
    }

    final newKey = _normalizeId(synchronized.id);
    await box.put(newKey, synchronized.toJson());

    // Clean up any pending SyncQueueItem for this consultation to prevent duplicate replay
    try {
      final syncBox = hiveService.syncQueueBox;
      final keysToDelete = <dynamic>[];
      for (final entry in syncBox.toMap().entries) {
        final val = entry.value;
        final entity = val['entity']?.toString();
        if (entity == 'consultations' || entity == 'consultation') {
          final p = val['payload'];
          if (p is Map) {
            final pUuid =
                p['client_uuid']?.toString() ?? p['clientUuid']?.toString();
            final pId = p['id']?.toString();
            if ((clientUuid != null && pUuid == clientUuid) ||
                (pId != null &&
                    (pId == localConsultation.id || pId == synchronized.id))) {
              keysToDelete.add(entry.key);
            }
          }
        }
      }
      for (final k in keysToDelete) {
        await syncBox.delete(k);
      }
    } catch (_) {}

    return synchronized;
  }

  /// Updates follow-up status for a consultation.
  Future<void> updateFollowUpStatus(
    String profileId,
    String consultationId, {
    required bool isDone,
  }) async {
    final existing = await getConsultationById(profileId, consultationId);
    if (existing != null) {
      final updated = existing.copyWith(
        isFollowUpDone: isDone,
        followUpStatus: isDone ? 'Completed' : 'Pending',
      );
      await saveConsultationModel(profileId, updated);
    }
  }

  /// Calculates dependent records (medicines & reports) linked to [consultationId].
  Future<EntityDependencies> getConsultationDependencies(
    String profileId,
    String consultationId,
  ) async {
    final box = hiveService.userBox;
    int medicineCount = 0;
    int reportCount = 0;

    for (final k in box.keys) {
      final kStr = k.toString();
      if (kStr.startsWith('medicine_') || kStr.startsWith('med_')) {
        final val = box.get(k);
        if (val is Map) {
          final storedProfId = (val['profile_id'] ?? val['profileId'])
              ?.toString();
          if (IdUtils.matchesProfileId(
            storedProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final cId =
                (val['linked_consultation_id'] ?? val['linkedConsultationId'])
                    ?.toString();
            if (IdUtils.matches(cId, consultationId)) {
              medicineCount++;
            }
          }
        }
      } else if (kStr.startsWith('report_') || kStr.startsWith('rep_')) {
        final val = box.get(k);
        if (val is Map) {
          final storedProfId = (val['profile_id'] ?? val['profileId'])
              ?.toString();
          if (IdUtils.matchesProfileId(
            storedProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final cId = (val['consultation_id'] ?? val['consultationId'])
                ?.toString();
            if (IdUtils.matches(cId, consultationId)) {
              reportCount++;
            }
          }
        }
      }
    }

    return EntityDependencies(medicines: medicineCount, reports: reportCount);
  }

  /// Deletes a consultation by [consultationId] for [profileId] if there are no dependencies.
  /// Does NOT delete doctors, hospitals, departments, reports, or medicines.
  /// Throws [ResourceHasDependenciesException] if dependent medicines or reports exist.
  Future<void> deleteConsultation(
    String profileId,
    String consultationId,
  ) async {
    final key = _normalizeId(consultationId);
    final box = hiveService.userBox;
    final val = box.get(key) ?? box.get(consultationId);
    if (val == null) return;

    final existing = await getConsultationById(profileId, consultationId);

    final deps = await getConsultationDependencies(profileId, consultationId);
    if (deps.hasDependencies) {
      throw ResourceHasDependenciesException(
        'Cannot delete this consultation. This consultation has linked records and cannot be permanently deleted while these records depend on it.',
        dependencyCounts: {
          'medicines': deps.medicines,
          'reports': deps.reports,
        },
      );
    }

    final serverId = IdUtils.toServerIntId(consultationId);
    final isNumericServerId = serverId != null;

    // 1. Delete from local Hive first
    await box.delete(key);
    await box.delete(consultationId);

    // 2. If local-only consultation is deleted, remove any pending create/update queue items
    if (!isNumericServerId) {
      try {
        final syncBox = hiveService.syncQueueBox;
        final keysToDelete = <dynamic>[];
        for (final entry in syncBox.toMap().entries) {
          final val = entry.value;
          final entity = val['entity']?.toString().toLowerCase();
          if (entity == 'consultations' || entity == 'consultation') {
            final p = val['payload'];
            if (p is Map) {
              final pId = p['id']?.toString();
              if (pId == key ||
                  pId == consultationId ||
                  IdUtils.matches(pId, consultationId) ||
                  (val['id']?.toString() == consultationId)) {
                keysToDelete.add(entry.key);
              }
            }
          }
        }
        for (final k in keysToDelete) {
          await syncBox.delete(k);
        }
      } catch (_) {}
    }

    // 3. Clean up attachment files using safe ownership check
    if (existing != null && existing.attachments.isNotEmpty) {
      final pathsToDelete = existing.attachments
          .map((att) => att.filePath)
          .whereType<String>()
          .toList();
      if (pathsToDelete.isNotEmpty) {
        await AttachmentCleanupHelper.safelyDeleteFiles(
          hiveService: hiveService,
          filePaths: pathsToDelete,
          exemptRecordId: key,
        );
      }
    }

    bool deletedRemotely = false;
    if (connectivityService != null &&
        remoteDataSource != null &&
        isNumericServerId) {
      final isOnline = await connectivityService!.checkConnectivity();
      if (isOnline) {
        try {
          await remoteDataSource!.deleteConsultation(serverId.toString());
          deletedRemotely = true;
        } catch (_) {
          deletedRemotely = false;
        }
      }
    }

    if (!deletedRemotely && isNumericServerId) {
      await syncService?.addToQueue(
        SyncQueueItem(
          id: 'sync_delete_consultation_${DateTime.now().microsecondsSinceEpoch}',
          entity: 'consultations',
          operation: 'delete',
          payload: {
            'id': key,
            'profile_id': profileId,
            if (existing?.clientUuid != null)
              'client_uuid': existing!.clientUuid,
          },
        ),
      );
    }
  }

  /// Downloads a binary file attachment associated with [consultationId] and [fileId].
  Future<Uint8List> downloadAttachment(
    String consultationId,
    String fileId,
  ) async {
    if (remoteDataSource == null) {
      throw const FormatException(
        'Remote data source not available for download.',
      );
    }
    final cleanConsultationId =
        IdUtils.toServerIntId(consultationId)?.toString() ??
        consultationId.replaceFirst('consultation_', '');
    final cleanFileId =
        IdUtils.toServerIntId(fileId)?.toString() ??
        fileId.replaceFirst('att_', '');
    return await remoteDataSource!.downloadConsultationAttachment(
      cleanConsultationId,
      cleanFileId,
    );
  }

  /// Resolves the physical [File] for consultation [attachment]. If missing on disk,
  /// downloads via C6, saves it to persistent profile storage, and updates the local Hive
  /// record with the new filePath.
  Future<File?> getOrDownloadAttachmentFile({
    required String profileId,
    required String consultationId,
    required ConsultationAttachment attachment,
    Directory? customBaseDirectory,
  }) async {
    // 1. Check if local file exists on disk
    if (attachment.filePath != null && attachment.filePath!.trim().isNotEmpty) {
      final localFile = File(attachment.filePath!);
      if (localFile.existsSync()) {
        return localFile;
      }
    }

    // 2. Check if remote download is possible
    if (remoteDataSource == null) {
      return null;
    }

    final cleanConsultationId =
        IdUtils.toServerIntId(consultationId) ??
        int.tryParse(IdUtils.unprefix(consultationId));
    final cleanFileId =
        IdUtils.toServerIntId(attachment.id) ??
        int.tryParse(IdUtils.unprefix(attachment.id));

    if (cleanConsultationId == null || cleanFileId == null) {
      return null;
    }

    // 3. Download binary bytes from C6
    try {
      final bytes = await remoteDataSource!.downloadConsultationAttachment(
        cleanConsultationId.toString(),
        cleanFileId.toString(),
      );

      // 4. Save to persistent profile storage
      Directory appDir;
      if (customBaseDirectory != null) {
        appDir = customBaseDirectory;
      } else {
        try {
          appDir = await getApplicationDocumentsDirectory();
        } catch (_) {
          appDir = Directory.systemTemp;
        }
      }
      final targetDir = Directory(
        '${appDir.path}/profiles/$profileId/consultations/attachments',
      );
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String ext = 'bin';
      if (attachment.name.contains('.')) {
        ext = attachment.name.split('.').last.toLowerCase();
      } else if (attachment.fileType != null &&
          attachment.fileType!.contains('/')) {
        ext = attachment.fileType!.split('/').last.toLowerCase();
      }
      final destPath =
          '${targetDir.path}/consultation_${cleanConsultationId}_att_${cleanFileId}_$timestamp.$ext';
      final file = File(destPath);
      await file.writeAsBytes(bytes, flush: true);

      // 5. Update local Hive consultation model with the persistent filePath
      final box = hiveService.userBox;
      final key = _normalizeId(consultationId);
      final raw = box.get(key) ?? box.get(consultationId);
      if (raw is Map) {
        final existing = ConsultationModel.fromJson(
          Map<String, dynamic>.from(raw),
        );
        final updatedAttachments = existing.attachments.map((a) {
          if (a.id == attachment.id || a.name == attachment.name) {
            return a.copyWith(filePath: destPath);
          }
          return a;
        }).toList();

        final updatedConsultation = existing.copyWith(
          attachments: updatedAttachments,
        );
        await box.put(key, updatedConsultation.toJson());
      }

      return file;
    } on AppException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  /// Derived lookup: returns the ConsultationModel linked to [appointmentId] for [profileId].
  /// Enforces profile isolation by verifying that consultation.profileId == profileId.
  Future<ConsultationModel?> getConvertedConsultation(
    String profileId,
    String appointmentId,
  ) async {
    final consultations = await getConsultationModels(profileId);
    final cleanAppointmentId = IdUtils.unprefix(appointmentId);
    return consultations.where((c) {
      if (c.profileId != profileId) return false;
      if (c.appointmentId == null || c.appointmentId!.isEmpty) return false;
      return IdUtils.matches(c.appointmentId, appointmentId) ||
          IdUtils.matches(c.appointmentId, cleanAppointmentId);
    }).firstOrNull;
  }
}
