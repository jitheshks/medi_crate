import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../../core/api/list_pull_support.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../../core/storage/attachment_cleanup_helper.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/models/sync_queue_item.dart';
import '../../../../core/sync/pending_mutation_guard.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../datasources/remote/report_remote_data_source.dart';
import '../models/report_model.dart';
import '../../presentation/widgets/form/report_attachment_helper.dart';

/// ReportRepository manages profile-scoped diagnostic reports, lab results,
/// prescriptions, and medical files in Hive storage with REST API synchronization (R1 - R6).
class ReportRepository {
  final HiveService hiveService;
  final SyncService? syncService;
  final ReportRemoteDataSource? remoteDataSource;
  final ConnectivityService? connectivityService;

  /// Post-pull freshness signal (Phase 3): invoked once, after the Hive merge,
  /// only when a pull actually changed local state.
  final void Function()? onPullMerged;

  final Map<String, Future<void>> _inFlightPulls = {};

  /// Whether the last completed pull retrieved the full server dataset
  /// (`received >= data.total`). Exposed for tests.
  bool lastPullComplete = true;

  ReportRepository({
    required this.hiveService,
    this.syncService,
    this.remoteDataSource,
    this.connectivityService,
    this.onPullMerged,
  });

  /// Normalizes report ID to ensure Hive key prefix.
  String _normalizeReportId(String rawId) {
    if (rawId.startsWith('report_')) return rawId;
    return 'report_$rawId';
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
  }) async {
    // 1. Dispatch background pull-sync asynchronously (unawaited)
    if (remoteDataSource != null) {
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
        ),
      );
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
  }) {
    if (remoteDataSource == null) return Future.value();
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
  }) async {
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
        (fetchLimit, onTotal) => remoteDataSource!.fetchReports(
          profileId: numericProfileId,
          category: category,
          consultationId: consultationId,
          doctorId: doctorId,
          hospitalId: hospitalId,
          search: search,
          from: from,
          to: to,
          sort: sort,
          page: page,
          limit: fetchLimit,
          onTotal: onTotal,
        ),
        onComplete: (c) => lastPullComplete = c,
      );
      final box = hiveService.userBox;
      bool pulledChanged = false;

      for (final raw in remoteList) {
        final remoteModel = ReportModel.fromJson(raw);
        final cleanId = remoteModel.id.isNotEmpty
            ? remoteModel.id
            : (raw['id']?.toString() ?? '');
        final id = _normalizeReportId(cleanId);

        // Guard against overwriting pending local mutations (I2-C2)
        if (PendingMutationGuard.hasPendingMutation(
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
        final existingRaw = box.get(id) ?? box.get(cleanId);
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
            mergedAttachments.add(rAtt.copyWith(filePath: localMatch.filePath));
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
    } catch (_) {
      // Fallback gracefully to local Hive cache on remote error / offline
    } finally {
      _inFlightPulls.remove(profileId);
    }
  }

  /// Backward-compatible raw JSON map getter for AnalyticsRepository & Legacy caller code.
  Future<List<Map<String, dynamic>>> getReports(String profileId) async {
    final models = await getReportsForProfile(profileId);
    return models.map((m) => m.toJson()).toList();
  }

  /// Loads single report by [reportId] for [profileId] with offline-first synchronization (R3).
  Future<ReportModel?> getReportById(String profileId, String reportId) async {
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

    // 3. Fallback to remote if missing locally and online
    final serverId = IdUtils.toServerIntId(cleanTarget);
    if (remoteDataSource != null && serverId != null) {
      final isOnline = connectivityService != null
          ? await connectivityService!.checkConnectivity()
          : true;

      if (isOnline) {
        try {
          final remoteMap = await remoteDataSource!.getReport(serverId);
          if (remoteMap.isNotEmpty) {
            final remoteModel = ReportModel.fromJson(remoteMap);

            // Guard against overwriting pending local mutations (I2-C2)
            if (!PendingMutationGuard.hasPendingMutation(
              syncQueueBox: hiveService.syncQueueBox,
              profileBox: hiveService.profileBox,
              entity: 'report',
              profileId: profileId,
              remoteId: key,
              clientUuid: remoteModel.clientUuid,
            )) {
              final existingRaw =
                  box.get(key) ??
                  box.get(reportId) ??
                  box.get(serverId.toString());

              ReportModel merged = remoteModel.copyWith(
                id: key,
                profileId: profileId,
              );

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
                  clientUuid:
                      existingModel.clientUuid ?? remoteModel.clientUuid,
                  notes: (merged.notes != null && merged.notes!.isNotEmpty)
                      ? merged.notes
                      : existingModel.notes,
                );
              }

              await box.put(key, merged.toJson());
              return merged;
            }
          }
        } catch (_) {
          // Fallback gracefully to local Hive cache
        }
      }
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

  /// Resolves the physical [File] for [attachment]. If missing on disk, downloads via R6,
  /// saves it to persistent profile storage, and updates the local Hive record with the new filePath.
  Future<File?> getOrDownloadAttachmentFile({
    required String profileId,
    required String reportId,
    required ReportAttachmentModel attachment,
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

    final cleanReportId =
        IdUtils.toServerIntId(reportId) ??
        int.tryParse(IdUtils.unprefix(reportId));
    final cleanFileId =
        IdUtils.toServerIntId(attachment.id) ??
        int.tryParse(IdUtils.unprefix(attachment.id));

    if (cleanReportId == null || cleanFileId == null) {
      return null;
    }

    // 3. Download binary bytes from R6
    try {
      final bytes = await remoteDataSource!.downloadReportAttachment(
        cleanReportId,
        cleanFileId,
      );

      // 4. Save to persistent profile storage
      final savedModel =
          await ReportAttachmentHelper.saveBytesToPersistentStorage(
            bytes: bytes,
            profileId: profileId,
            fileName: attachment.name,
            fileType: attachment.fileType,
            attachmentId: attachment.id,
          );

      // 5. Update local Hive report model with the persistent filePath
      final existingReport = await getReportById(profileId, reportId);
      if (existingReport != null) {
        final updatedAttachments = existingReport.attachments.map((a) {
          if (a.id == attachment.id || a.name == attachment.name) {
            return a.copyWith(filePath: savedModel.filePath);
          }
          return a;
        }).toList();

        final updatedReport = existingReport.copyWith(
          attachments: updatedAttachments,
        );
        final box = hiveService.userBox;
        await box.put(_normalizeReportId(reportId), updatedReport.toJson());
      }

      if (savedModel.filePath != null) {
        return File(savedModel.filePath!);
      }
    } on AppException {
      // Surface typed API failures (network / 404 / 401 / 403 / 5xx) so the
      // caller can present an accurate reason instead of a generic message.
      rethrow;
    } catch (_) {
      // Genuinely unexpected/local failures fall back to null; caller handles it.
    }

    return null;
  }

  /// Returns report count for active [profileId].
  Future<int> getReportCount(String profileId) async {
    final reports = await getReportsForProfile(profileId);
    return reports.length;
  }

  /// Saves or updates [report] in Hive and queues sync operation.
  Future<ReportModel> saveReport(String profileId, ReportModel report) async {
    final rawId = report.id.isNotEmpty
        ? report.id
        : 'report_${DateTime.now().microsecondsSinceEpoch}';
    final id = _normalizeReportId(rawId);

    final box = hiveService.userBox;
    final existingRaw = box.get(id) ?? box.get(rawId);
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
  Future<void> deleteReport(String profileId, String reportId) async {
    final existingReport = await getReportById(profileId, reportId);
    final key = _normalizeReportId(reportId);
    final serverId = IdUtils.toServerIntId(reportId);
    final isNumericServerId = serverId != null;

    // 1. Delete from local Hive first
    final box = hiveService.userBox;
    await box.delete(key);
    await box.delete(reportId);

    // 2. If local-only report is deleted, remove any pending create/update queue items
    if (!isNumericServerId) {
      try {
        final syncBox = hiveService.syncQueueBox;
        final keysToDelete = <dynamic>[];
        for (final entry in syncBox.toMap().entries) {
          final val = entry.value;
          final entity = val['entity']?.toString().toLowerCase();
          if (entity == 'reports' || entity == 'report') {
            final p = val['payload'];
            if (p is Map) {
              final pId = p['id']?.toString();
              if (pId == key ||
                  pId == reportId ||
                  IdUtils.matches(pId, reportId) ||
                  (val['id']?.toString() == reportId)) {
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

    // 4. Queue delete if server numeric ID
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
