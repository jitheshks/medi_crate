import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../core/storage/attachment_cleanup_helper.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/storage/supabase_storage_service.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/pulled_record_comparison.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/supabase_report_remote_data_source.dart';
import '../models/report_model.dart';

/// ReportRepository manages profile-scoped diagnostic reports, lab results,
/// prescriptions, and medical files in Hive storage with native Supabase and Storage integration.
class ReportRepository {
  final HiveService hiveService;
  final SyncService? syncService;
  final SupabaseReportRemoteDataSource? supabaseRemoteDataSource;
  final ConnectivityService? connectivityService;
  final SupabaseStorageService? storageService;

  /// Post-pull freshness signal: invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  ReportRepository({
    required this.hiveService,
    this.syncService,
    this.supabaseRemoteDataSource,
    this.connectivityService,
    this.storageService,
    this.onPullMerged,
    dynamic remoteDataSource,
  });

  /// Normalizes report ID to ensure Hive key prefix.
  String _normalizeReportId(String rawId) {
    if (rawId.startsWith('report_')) return rawId;
    return 'report_$rawId';
  }

  String? _resolveCurrentUserId([String? explicitOwnerUserId]) {
    if (explicitOwnerUserId != null && explicitOwnerUserId.trim().isNotEmpty) {
      return explicitOwnerUserId.trim();
    }
    try {
      if (SupabaseConfig.isInitialized) {
        final sessionUid = SupabaseConfig.client.auth.currentUser?.id;
        if (sessionUid != null && sessionUid.trim().isNotEmpty) {
          return sessionUid.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  String? _resolveProfileUuid(String profileId, String ownerUserId) {
    final clean = IdUtils.unprefix(profileId).trim();
    try {
      final box = hiveService.profileBox;
      final raw =
          box.get(profileId) ?? box.get(clean) ?? box.get('prof_$clean');
      Map? direct;
      if (raw is Map) {
        direct = raw;
      } else {
        for (final val in box.values) {
          final pId =
              (val['profile_id'] ?? val['profileId'] ?? val['id'])?.toString();
          if (pId != null &&
              (IdUtils.matches(pId, profileId) || IdUtils.matches(pId, clean))) {
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

        final id =
            (direct['profile_id'] ?? direct['profileId'] ?? direct['id'])?.toString();
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

  Future<void> _cleanupSyncQueue(
    String key,
    String? rawId,
    String? clientUuid,
  ) async {
    try {
      final syncBox = hiveService.syncQueueBox;
      final keysToDelete = <dynamic>[];
      for (final entry in syncBox.toMap().entries) {
        final val = entry.value;
        final entity = val['entity']?.toString().toLowerCase();
        if (entity == 'reports' || entity == 'report') {
          final p = val['payload'];
          if (p is Map) {
            final pUuid =
                p['client_uuid']?.toString() ?? p['clientUuid']?.toString();
            final pId = p['id']?.toString();
            if ((clientUuid != null &&
                    clientUuid.isNotEmpty &&
                    pUuid == clientUuid) ||
                (pId != null &&
                    (pId == key ||
                        pId == rawId ||
                        pId == IdUtils.unprefix(key) ||
                        (rawId != null && pId == IdUtils.unprefix(rawId))))) {
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

  /// Retrieves typed [ReportModel] list scoped to [profileId] immediately from local Hive cache (R1),
  /// and dispatches a non-blocking background pull-sync when online.
  Future<List<ReportModel>> getReportsForProfile(
    String profileId, {
    String? category,
    int? consultationId,
    int? doctorId,
    int? hospitalId,
    String? search,
    String? from,
    String? to,
    String? sort,
    int? page,
    int limit = 20,
    String? explicitOwnerUserId,
  }) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (supabaseRemoteDataSource != null) {
      unawaited(
        pullReports(
          profileId,
          category: category,
          consultationId: consultationId,
          doctorId: doctorId,
          hospitalId: hospitalId,
          search: search,
          from: from,
          to: to,
          sort: sort,
          page: page,
          limit: limit,
          explicitOwnerUserId: explicitOwnerUserId,
        ),
      );
    }

    // Reject foreign profiles if user session or explicitOwnerUserId is present
    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
      if (ownerUserId != null) {
        final resolvedProfile = _resolveProfileUuid(profileId, ownerUserId);
        if (resolvedProfile == null) {
          return [];
        }
      }
    }

    // 2. Return local Hive records immediately
    final box = hiveService.userBox;
    final reports = <ReportModel>[];

    for (final key in box.keys) {
      if (key.toString().startsWith('report_')) {
        final val = box.get(key);
        if (val is Map) {
          final map = Map<String, dynamic>.from(val);
          final storedProfId = (map['profile_id'] ?? map['profileId'])
              ?.toString();
          if (IdUtils.matchesProfileId(
            storedProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            reports.add(ReportModel.fromJson(map));
          }
        }
      }
    }

    // Default sort: Newest first
    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports;
  }

  /// Performs background pull-sync for reports belonging to [profileId]
  /// and merges server records into Hive cache.
  Future<void> pullReports(
    String profileId, {
    String? category,
    int? consultationId,
    int? doctorId,
    int? hospitalId,
    String? search,
    String? from,
    String? to,
    String? sort,
    int? page,
    int limit = 20,
    String? explicitOwnerUserId,
  }) {
    if (supabaseRemoteDataSource == null) {
      return Future.value();
    }
    final existing = _inFlightPulls[profileId];
    if (existing != null) return existing;

    final future = _executePullReports(
      profileId,
      category: category,
      consultationId: consultationId,
      doctorId: doctorId,
      hospitalId: hospitalId,
      search: search,
      from: from,
      to: to,
      sort: sort,
      page: page,
      limit: limit,
      explicitOwnerUserId: explicitOwnerUserId,
    );
    _inFlightPulls[profileId] = future;
    future.whenComplete(() {
      if (identical(_inFlightPulls[profileId], future)) {
        _inFlightPulls.remove(profileId);
      }
    });
    return future;
  }

  Future<void> _executePullReports(
    String profileId, {
    String? category,
    int? consultationId,
    int? doctorId,
    int? hospitalId,
    String? search,
    String? from,
    String? to,
    String? sort,
    int? page,
    int limit = 20,
    String? explicitOwnerUserId,
  }) async {
    try {
      if (supabaseRemoteDataSource != null) {
        final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
        if (ownerUserId == null || ownerUserId.isEmpty) return;

        final profileUuid = _resolveProfileUuid(profileId, ownerUserId);
        if (profileUuid == null || profileUuid.isEmpty) return;

        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (!isOnline) return;

        final remoteList = await supabaseRemoteDataSource!.fetchReports(
          ownerUserId: ownerUserId,
          profileId: profileUuid,
          category: category,
          search: search,
          from: from,
          to: to,
          limit: limit,
        );

        final box = hiveService.userBox;
        bool pulledChanged = false;

        for (final remoteModel in remoteList) {
          final id = _normalizeReportId(remoteModel.id);

          // Guard against overwriting pending local mutations (I2-C2)
          if (PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'reports',
                profileId: profileId,
                remoteId: id,
                clientUuid: remoteModel.clientUuid,
              ) ||
              PendingMutationGuard.hasPendingMutation(
                syncQueueBox: hiveService.syncQueueBox,
                profileBox: hiveService.profileBox,
                entity: 'report',
                profileId: profileId,
                remoteId: id,
                clientUuid: remoteModel.clientUuid,
              )) {
            continue;
          }

          // Merge with local data (preserve local attachment file paths if already on disk)
          final existingRaw = box.get(id) ?? box.get(remoteModel.id);
          ReportModel merged = remoteModel.copyWith(id: id, profileId: profileId);

          if (existingRaw is Map) {
            final existingModel = ReportModel.fromJson(
              Map<String, dynamic>.from(existingRaw),
            );

            // Merge attachments: preserve local filePath for cached files
            final mergedAttachments = <ReportAttachmentModel>[];
            for (final rAtt in remoteModel.attachments) {
              final localMatch = existingModel.attachments.firstWhere(
                (lAtt) =>
                    lAtt.id == rAtt.id ||
                    (lAtt.name == rAtt.name && lAtt.filePath != null),
                orElse: () => rAtt,
              );
              mergedAttachments.add(
                rAtt.copyWith(filePath: localMatch.filePath),
              );
            }

            merged = merged.copyWith(
              attachments: mergedAttachments.isNotEmpty
                  ? mergedAttachments
                  : existingModel.attachments,
              clientUuid: existingModel.clientUuid ?? remoteModel.clientUuid,
              notes: (merged.notes != null && merged.notes!.isNotEmpty)
                  ? merged.notes
                  : existingModel.notes,
            );
          }

          final encoded = merged.toJson();
          if (pulledRecordChanged(box.get(id), encoded)) pulledChanged = true;
          await box.put(id, encoded);
        }

        if (pulledChanged) {
          try {
            onPullMerged?.call();
          } catch (_) {}
        }
        return;
      }
    } catch (_) {
      // Fallback gracefully to local Hive cache on remote error / offline
    } finally {
      _inFlightPulls.remove(profileId);
    }
  }

  /// Backward-compatible raw JSON map getter for AnalyticsRepository & untyped callers.
  Future<List<Map<String, dynamic>>> getReports(String profileId) async {
    final models = await getReportsForProfile(profileId);
    return models.map((m) => m.toJson()).toList();
  }

  /// Loads single report by [reportId] for [profileId] with offline-first synchronization (R3).
  Future<ReportModel?> getReportById(
    String profileId,
    String reportId, {
    String? explicitOwnerUserId,
  }) async {
    final cleanTarget = IdUtils.unprefix(reportId);
    final key = _normalizeReportId(reportId);
    final box = hiveService.userBox;

    // 1. Check local Hive box first (Offline-first & immediate consistency)
    var val = box.get(key) ?? box.get(reportId) ?? box.get(cleanTarget);
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final storedProfId = (map['profile_id'] ?? map['profileId'])?.toString();
      if (IdUtils.matchesProfileId(
        storedProfId,
        profileId,
        profileBox: hiveService.profileBox,
      )) {
        return ReportModel.fromJson(map);
      }
    }

    // 2. Comprehensive local scan by key / IdUtils / client_uuid
    for (final k in box.keys) {
      if (k.toString().startsWith('report_') ||
          k.toString().startsWith('rep_')) {
        final raw = box.get(k);
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          final storedProfId = (map['profile_id'] ?? map['profileId'])
              ?.toString();
          if (IdUtils.matchesProfileId(
            storedProfId,
            profileId,
            profileBox: hiveService.profileBox,
          )) {
            final id = (map['id'] ?? '').toString();
            final clientUuid = (map['client_uuid'] ?? map['clientUuid'])
                ?.toString();
            if (k == key ||
                k == reportId ||
                IdUtils.matches(id, reportId) ||
                (clientUuid != null &&
                    clientUuid.isNotEmpty &&
                    (clientUuid == reportId ||
                        IdUtils.matches(clientUuid, reportId)))) {
              return ReportModel.fromJson(map);
            }
          }
        }
      }
    }

    // 3. Fallback to Supabase if missing locally and online
    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(profileId, ownerUserId)
          : null;
      if (ownerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            final remoteModel = await supabaseRemoteDataSource!.getReportById(
              reportId: cleanTarget,
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            if (remoteModel != null) {
              if (!PendingMutationGuard.hasPendingMutation(
                    syncQueueBox: hiveService.syncQueueBox,
                    profileBox: hiveService.profileBox,
                    entity: 'reports',
                    profileId: profileId,
                    remoteId: key,
                    clientUuid: remoteModel.clientUuid,
                  ) &&
                  !PendingMutationGuard.hasPendingMutation(
                    syncQueueBox: hiveService.syncQueueBox,
                    profileBox: hiveService.profileBox,
                    entity: 'report',
                    profileId: profileId,
                    remoteId: key,
                    clientUuid: remoteModel.clientUuid,
                  )) {
                final existingRaw =
                    box.get(key) ?? box.get(reportId) ?? box.get(cleanTarget);
                ReportModel merged = remoteModel.copyWith(
                  id: key,
                  profileId: profileId,
                );
                if (existingRaw is Map) {
                  final existingModel = ReportModel.fromJson(
                    Map<String, dynamic>.from(existingRaw),
                  );
                  final mergedAttachments = <ReportAttachmentModel>[];
                  for (final rAtt in remoteModel.attachments) {
                    final localMatch = existingModel.attachments.firstWhere(
                      (lAtt) =>
                          lAtt.id == rAtt.id ||
                          (lAtt.name == rAtt.name && lAtt.filePath != null),
                      orElse: () => rAtt,
                    );
                    mergedAttachments.add(
                      rAtt.copyWith(filePath: localMatch.filePath),
                    );
                  }
                  merged = merged.copyWith(
                    attachments: mergedAttachments.isNotEmpty
                        ? mergedAttachments
                        : existingModel.attachments,
                    clientUuid:
                        existingModel.clientUuid ?? remoteModel.clientUuid,
                  );
                }
                await box.put(key, merged.toJson());
                return merged;
              }
            }
          } catch (_) {}
        }
      }
      return null;
    }

    final reports = await getReportsForProfile(profileId);
    try {
      return reports.firstWhere(
        (r) =>
            IdUtils.matches(r.id, reportId) ||
            r.id == key ||
            (r.clientUuid != null &&
                (r.clientUuid == reportId ||
                    IdUtils.matches(r.clientUuid, reportId))),
      );
    } catch (_) {
      return null;
    }
  }

  /// Resolves the physical [File] for [attachment]. If missing on disk, downloads via Storage,
  /// saves it to persistent profile storage, and updates the local Hive record with the new filePath.
  Future<File?> getOrDownloadAttachmentFile({
    required String profileId,
    required String reportId,
    required ReportAttachmentModel attachment,
    String? explicitOwnerUserId,
    Directory? customBaseDirectory,
  }) async {
    // 1. Check if local file exists on disk
    if (attachment.filePath != null && attachment.filePath!.trim().isNotEmpty) {
      final localFile = File(attachment.filePath!);
      if (localFile.existsSync()) {
        return localFile;
      }
    }

    // 2. Check if remote download via Supabase Storage is possible
    if (storageService != null &&
        attachment.fileUrl != null &&
        attachment.fileUrl!.trim().isNotEmpty) {
      try {
        final bytes = await storageService!.downloadBytes(
          bucket: SupabaseStorageService.reportsBucket,
          storagePath: attachment.fileUrl!.trim(),
        );
        if (bytes.isNotEmpty) {
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
            '${appDir.path}/profiles/$profileId/reports/attachments',
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
          final cleanReportId = IdUtils.unprefix(reportId);
          final cleanFileId = IdUtils.unprefix(attachment.id);
          final destPath =
              '${targetDir.path}/report_${cleanReportId}_att_${cleanFileId}_$timestamp.$ext';
          final file = File(destPath);
          await file.writeAsBytes(bytes, flush: true);

          // Update local Hive record with new filePath
          final normId = _normalizeReportId(reportId);
          final box = hiveService.userBox;
          final existing = box.get(normId) ?? box.get(reportId) ?? box.get(cleanReportId);
          if (existing is Map) {
            final model = ReportModel.fromJson(
              Map<String, dynamic>.from(existing),
            );
            final updatedAttachments = model.attachments.map((a) {
              if (a.id == attachment.id || a.name == attachment.name) {
                return a.copyWith(filePath: file.path);
              }
              return a;
            }).toList();
            final updatedModel =
                model.copyWith(attachments: updatedAttachments);
            await box.put(normId, updatedModel.toJson());
          }
          return file;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Returns report count for active [profileId].
  Future<int> getReportCount(String profileId) async {
    final reports = await getReportsForProfile(profileId);
    return reports.length;
  }

  /// Saves or updates [report] in Hive and synchronizes with Supabase / queues sync operation.
  Future<ReportModel> saveReport(
    String profileId,
    ReportModel report, {
    String? explicitOwnerUserId,
  }) async {
    final rawId = report.id.isNotEmpty
        ? report.id
        : 'report_${DateTime.now().microsecondsSinceEpoch}';
    final cleanId = IdUtils.unprefix(rawId).trim();
    final isNew = rawId.isEmpty ||
        rawId.startsWith('temp_') ||
        !UuidUtils.isValidUuid(cleanId);
    final id = _normalizeReportId(rawId);

    final box = hiveService.userBox;
    final existingRaw = box.get(id) ??
        box.get(rawId) ??
        (cleanId.isNotEmpty ? box.get(cleanId) : null);
    String? existingUuid;
    if (existingRaw is Map) {
      existingUuid =
          existingRaw['client_uuid']?.toString() ??
          existingRaw['clientUuid']?.toString();
    }

    final clientUuid =
        (report.clientUuid != null && report.clientUuid!.trim().isNotEmpty)
            ? report.clientUuid!.trim()
            : (existingUuid ?? UuidUtils.generateV4());

    final updated = report.copyWith(
      id: id,
      profileId: profileId,
      clientUuid: clientUuid,
      updatedAt: DateTime.now(),
    );

    final hiveKey = id;
    await box.put(hiveKey, updated.toJson());

    // Clean up any removed attachments from disk if updating an existing report
    if (existingRaw is Map) {
      try {
        final oldModel = ReportModel.fromJson(
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

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(profileId, ownerUserId)
          : null;
      final isExistingUuid = !isNew && UuidUtils.isValidUuid(cleanId);

      if (ownerUserId != null && profileUuid != null) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            final targetReportId =
                isExistingUuid ? cleanId : UuidUtils.generateV4();

            // Upload any attachments that have local `filePath` and need storage
            final List<ReportAttachmentModel> processedAttachments = [];
            for (final att in updated.attachments) {
              String? fileUrl = att.fileUrl;
              if (att.filePath != null && att.filePath!.trim().isNotEmpty) {
                final localFile = File(att.filePath!.trim());
                if (localFile.existsSync() &&
                    (fileUrl == null ||
                        fileUrl.trim().isEmpty ||
                        !fileUrl.contains('/'))) {
                  fileUrl = await supabaseRemoteDataSource!.uploadAttachmentFile(
                    userId: ownerUserId,
                    reportId: targetReportId,
                    file: localFile,
                    customAttachmentId:
                        UuidUtils.isValidUuid(IdUtils.unprefix(att.id))
                            ? IdUtils.unprefix(att.id)
                            : null,
                    fileName: att.name,
                  );
                }
              }
              processedAttachments.add(att.copyWith(fileUrl: fileUrl));
            }

            final reportForRemote = updated.copyWith(
              id: targetReportId,
              profileId: profileUuid,
              attachments: processedAttachments,
            );

            ReportModel remoteResult;
            if (isExistingUuid) {
              remoteResult = await supabaseRemoteDataSource!.updateReport(
                report: reportForRemote,
                ownerUserId: ownerUserId,
                profileId: profileUuid,
              );
            } else {
              remoteResult = await supabaseRemoteDataSource!.createReport(
                report: reportForRemote,
                ownerUserId: ownerUserId,
                profileId: profileUuid,
              );
            }

            // Preserve local filePaths for attachments in Hive
            final List<ReportAttachmentModel> mergedAttachments = [];
            for (final rAtt in remoteResult.attachments) {
              final localMatch = processedAttachments.firstWhere(
                (pAtt) => pAtt.id == rAtt.id || pAtt.name == rAtt.name,
                orElse: () => rAtt,
              );
              mergedAttachments.add(
                rAtt.copyWith(filePath: localMatch.filePath ?? rAtt.filePath),
              );
            }

            final serverId = remoteResult.id;
            final serverKey = _normalizeReportId(serverId);
            final synced = remoteResult.copyWith(
              id: serverKey,
              profileId: profileId,
              clientUuid: clientUuid,
              attachments: mergedAttachments,
            );

            if (!isExistingUuid) {
              await box.delete(rawId);
              await box.delete(_normalizeReportId(rawId));
              await box.delete(id);
              if (cleanId.isNotEmpty) await box.delete(cleanId);
            }
            await box.put(serverKey, synced.toJson());

            // Clean up sync queue:
            await _cleanupSyncQueue(serverKey, rawId, clientUuid);
            return synced;
          } catch (_) {
            // Fall back to queueing offline mutation
          }
        }

        // Offline or network error: enqueue mutation
        await syncService?.addToQueue(
          SyncQueueItem(
            id: 'sync_report_${DateTime.now().millisecondsSinceEpoch}',
            entity: 'reports',
            operation: isExistingUuid ? 'update' : 'create',
            payload: updated.toJson(),
          ),
        );
        return updated;
      }

      // Unauthenticated or foreign profile
      return updated;
    }

    // Legacy branch ONLY when supabaseRemoteDataSource == null
    final serverId = IdUtils.toServerIntId(report.id);
    final isNumericServerId = serverId != null;

    if (syncService != null) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_report_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'reports',
          operation: isNumericServerId ? 'update' : 'create',
          payload: updated.toJson(),
        ),
      );
    }

    return updated;
  }

  /// Deletes report by [reportId] from local storage and cleans up attached files.
  Future<void> deleteReport(
    String profileId,
    String reportId, {
    String? explicitOwnerUserId,
  }) async {
    final existingReport = await getReportById(
      profileId,
      reportId,
      explicitOwnerUserId: explicitOwnerUserId,
    );
    final key = _normalizeReportId(reportId);
    final cleanId = IdUtils.unprefix(reportId).trim();

    // 1. Delete from local Hive first
    final box = hiveService.userBox;
    await box.delete(key);
    await box.delete(reportId);
    if (cleanId.isNotEmpty) await box.delete(cleanId);

    // 2. Clean up attachment files using safe ownership check
    if (existingReport != null && existingReport.attachments.isNotEmpty) {
      final pathsToDelete = existingReport.attachments
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

    if (supabaseRemoteDataSource != null) {
      final ownerUserId = _resolveCurrentUserId(explicitOwnerUserId);
      final profileUuid = ownerUserId != null
          ? _resolveProfileUuid(profileId, ownerUserId)
          : null;
      final isUuid = UuidUtils.isValidUuid(cleanId);

      bool deletedRemotely = false;
      if (ownerUserId != null && profileUuid != null && isUuid) {
        final isOnline = connectivityService != null
            ? await connectivityService!.checkConnectivity()
            : true;
        if (isOnline) {
          try {
            await supabaseRemoteDataSource!.deleteReport(
              reportId: cleanId,
              ownerUserId: ownerUserId,
              profileId: profileUuid,
            );
            deletedRemotely = true;
          } catch (_) {
            deletedRemotely = false;
          }
        }
      }

      if (!deletedRemotely &&
          isUuid &&
          ownerUserId != null &&
          profileUuid != null) {
        await syncService?.addToQueue(
          SyncQueueItem(
            id: 'sync_report_del_${DateTime.now().millisecondsSinceEpoch}',
            entity: 'reports',
            operation: 'delete',
            payload: {'id': key, 'profile_id': profileId},
          ),
        );
      }

      if (!isUuid) {
        await _cleanupSyncQueue(key, reportId, null);
      }
      return;
    }

    // Legacy branch ONLY when supabaseRemoteDataSource == null
    final serverId = IdUtils.toServerIntId(reportId);
    final isNumericServerId = serverId != null;

    if (!isNumericServerId) {
      await _cleanupSyncQueue(key, reportId, null);
    }

    if (syncService != null && isNumericServerId) {
      await syncService!.addToQueue(
        SyncQueueItem(
          id: 'sync_report_del_${DateTime.now().millisecondsSinceEpoch}',
          entity: 'reports',
          operation: 'delete',
          payload: {'id': serverId.toString(), 'profile_id': profileId},
        ),
      );
    }
  }

  /// Filters and sorts reports in memory.
  List<ReportModel> filterAndSortReports({
    required List<ReportModel> reports,
    required String query,
    required String categoryFilter,
    DateRangeSelection? dateRange,
    required String sortOption,
  }) {
    var filtered = reports.where((report) {
      // Date range filter check
      if (dateRange != null && !dateRange.isDateInRange(report.date)) {
        return false;
      }

      // Category filter check
      if (categoryFilter.toUpperCase() != 'ALL') {
        if (report.category.toUpperCase() != categoryFilter.toUpperCase()) {
          return false;
        }
      }

      // Search query check
      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchTitle = report.title.toLowerCase().contains(q);
        final matchCategory = report.category.toLowerCase().contains(q);
        final matchDoctor = (report.doctorName ?? '').toLowerCase().contains(q);
        final matchHospital = (report.hospitalName ?? '')
            .toLowerCase()
            .contains(q);
        final matchNotes = (report.notes ?? '').toLowerCase().contains(q);
        final matchAttachment = report.attachments.any(
          (a) => a.name.toLowerCase().contains(q),
        );

        if (!matchTitle &&
            !matchCategory &&
            !matchDoctor &&
            !matchHospital &&
            !matchNotes &&
            !matchAttachment) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sorting
    switch (sortOption) {
      case 'oldest':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'alphabetical':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'type':
        filtered.sort(
          (a, b) =>
              a.category.toLowerCase().compareTo(b.category.toLowerCase()),
        );
        break;
      case 'newest':
      default:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
    }

    return filtered;
  }

  /// Groups reports by Month and Year (e.g. "AUGUST 2026").
  Map<String, List<ReportModel>> groupReportsByMonthYear(
    List<ReportModel> reports,
  ) {
    final Map<String, List<ReportModel>> grouped = {};
    final DateFormat formatter = DateFormat('MMMM yyyy');

    for (final report in reports) {
      final key = formatter.format(report.date).toUpperCase();
      grouped.putIfAbsent(key, () => []).add(report);
    }

    return grouped;
  }
}
