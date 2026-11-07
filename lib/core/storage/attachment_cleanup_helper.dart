import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/id_utils.dart';
import 'hive_service.dart';

/// AttachmentCleanupHelper manages safe, ownership-verified deletion of local attachment files.
///
/// A physical file is safely deleted ONLY if:
/// 1. The path resides strictly within the canonical MediVault-managed profiles root directory
///    (e.g., `<appDocumentsDir>/profiles/...`), rejecting relative paths, root paths, external storage,
///    and path traversal escapes.
/// 2. The physical file exists on the filesystem.
/// 3. No other active record in [HiveService.userBox] or [HiveService.profileBox] references the file.
/// 4. No pending [SyncQueueItem] in [HiveService.syncQueueBox] references the file path.
class AttachmentCleanupHelper {
  static Directory? _customBaseDirectory;

  /// Sets a custom base directory for testing (acting as the application documents directory).
  @visibleForTesting
  static void setCustomBaseDirectory(Directory? dir) {
    _customBaseDirectory = dir;
  }

  /// Resolves the canonical managed profile attachment root directory (e.g. `<appDocumentsDir>/profiles`).
  static Future<String?> getManagedProfilesRoot({
    Directory? customBaseDirectory,
  }) async {
    final baseDir = customBaseDirectory ?? _customBaseDirectory;
    if (baseDir != null) {
      return p.canonicalize(p.join(baseDir.path, 'profiles'));
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return p.canonicalize(p.join(appDir.path, 'profiles'));
    } catch (_) {
      return null;
    }
  }

  /// Validates whether [filePath] resides strictly within MediVault's managed profiles root.
  ///
  /// Rejects:
  /// - null or empty paths
  /// - relative paths
  /// - root directory or outside directories
  /// - paths attempting traversal (..) to escape the managed root
  /// - paths outside the application documents directory's `/profiles` root
  /// - symlinks that resolve to files outside the managed root
  static Future<bool> isManagedProfilePath(
    String? filePath, {
    Directory? customBaseDirectory,
  }) async {
    if (filePath == null || filePath.trim().isEmpty) return false;
    final trimmed = filePath.trim();

    // Reject relative paths immediately
    if (p.isRelative(trimmed)) {
      return false;
    }

    final managedRoot = await getManagedProfilesRoot(
      customBaseDirectory: customBaseDirectory,
    );
    if (managedRoot == null || managedRoot.isEmpty) {
      return false;
    }

    final canonicalTarget = p.canonicalize(trimmed);

    // Check if canonical target is strictly within the managed root
    if (!p.isWithin(managedRoot, canonicalTarget)) {
      return false;
    }

    // If physical file exists, verify symbolic links do not escape the managed root
    final file = File(canonicalTarget);
    if (file.existsSync()) {
      try {
        final resolvedTarget = file.resolveSymbolicLinksSync();
        if (!p.isWithin(managedRoot, p.canonicalize(resolvedTarget))) {
          return false;
        }
      } catch (_) {
        // Fall back to canonicalTarget check if symlink resolution is not supported
      }
    }

    return true;
  }

  /// Safely deletes multiple [filePaths] in an operation-scoped batch.
  ///
  /// Resolves the managed profiles root once and collects referenced attachment paths
  /// across [HiveService.userBox], [HiveService.profileBox], and [HiveService.syncQueueBox]
  /// once for the entire batch.
  static Future<List<bool>> safelyDeleteFiles({
    required HiveService hiveService,
    required Iterable<String?> filePaths,
    String? exemptRecordId,
    Directory? customBaseDirectory,
  }) async {
    final pathList = filePaths.toList();
    if (pathList.isEmpty) return [];

    final results = List<bool>.filled(pathList.length, false);

    // 1. Resolve managed root once for the entire batch
    final managedRoot = await getManagedProfilesRoot(
      customBaseDirectory: customBaseDirectory,
    );
    if (managedRoot == null || managedRoot.isEmpty) {
      return results;
    }

    // 2. Validate paths, canonicalize, check existence and symlinks
    final candidates =
        <int, ({File file, String trimmed, String canonicalTarget})>{};

    for (int i = 0; i < pathList.length; i++) {
      final raw = pathList[i];
      if (raw == null || raw.trim().isEmpty) continue;
      final trimmed = raw.trim();

      if (p.isRelative(trimmed)) continue;

      final canonicalTarget = p.canonicalize(trimmed);
      if (!p.isWithin(managedRoot, canonicalTarget)) continue;

      final file = File(canonicalTarget);
      if (!file.existsSync()) continue;

      // Symlink escape validation
      try {
        final resolvedTarget = file.resolveSymbolicLinksSync();
        if (!p.isWithin(managedRoot, p.canonicalize(resolvedTarget))) {
          continue;
        }
      } catch (_) {
        // Fall back to canonicalTarget check if symlink resolution is unsupported
      }

      candidates[i] = (
        file: file,
        trimmed: trimmed,
        canonicalTarget: canonicalTarget,
      );
    }

    if (candidates.isEmpty) {
      return results;
    }

    // 3. Build operation-scoped reference set once across Hive & SyncQueue
    final referencedStrings = <String>{};

    // User box scan
    try {
      final userBox = hiveService.userBox;
      for (final key in userBox.keys) {
        if (exemptRecordId != null &&
            (key.toString() == exemptRecordId ||
                IdUtils.matches(key.toString(), exemptRecordId))) {
          continue;
        }
        final val = userBox.get(key);
        if (val != null) {
          _collectStrings(val, referencedStrings);
        }
      }
    } catch (_) {}

    // Profile box scan
    try {
      final profileBox = hiveService.profileBox;
      for (final key in profileBox.keys) {
        if (exemptRecordId != null &&
            (key.toString() == exemptRecordId ||
                IdUtils.matches(key.toString(), exemptRecordId))) {
          continue;
        }
        final val = profileBox.get(key);
        if (val != null) {
          _collectStrings(val, referencedStrings);
        }
      }
    } catch (_) {}

    // SyncQueue box scan
    try {
      final syncBox = hiveService.syncQueueBox;
      for (final key in syncBox.keys) {
        final val = syncBox.get(key);
        if (val is Map) {
          if (exemptRecordId != null) {
            final payload = val['payload'];
            if (payload is Map) {
              final pId = payload['id']?.toString();
              final pProfId =
                  payload['profile_id']?.toString() ??
                  payload['profileId']?.toString();
              if (pId != null &&
                  (pId == exemptRecordId ||
                      IdUtils.matches(pId, exemptRecordId))) {
                continue;
              }
              if (pProfId != null &&
                  (pProfId == exemptRecordId ||
                      IdUtils.matches(pProfId, exemptRecordId))) {
                continue;
              }
            }
          }
          _collectStrings(val, referencedStrings);
        }
      }
    } catch (_) {}

    // 4. Delete candidates that are not in the reference set
    for (final entry in candidates.entries) {
      final index = entry.key;
      final candidate = entry.value;

      if (referencedStrings.contains(candidate.trimmed) ||
          referencedStrings.contains(candidate.canonicalTarget)) {
        // Still referenced by an active record or sync queue item
        results[index] = false;
        continue;
      }

      try {
        await candidate.file.delete();
        results[index] = true;
      } catch (e) {
        debugPrint(
          '[AttachmentCleanupHelper] Error deleting orphaned file ${candidate.trimmed}: $e',
        );
        results[index] = false;
      }
    }

    return results;
  }

  /// Safely deletes [filePath] if it is genuinely inside managed profile storage
  /// and is unreferenced by any active record or pending sync item.
  static Future<bool> safelyDeleteFile({
    required HiveService hiveService,
    required String? filePath,
    String? exemptRecordId,
    Directory? customBaseDirectory,
  }) async {
    final results = await safelyDeleteFiles(
      hiveService: hiveService,
      filePaths: [filePath],
      exemptRecordId: exemptRecordId,
      customBaseDirectory: customBaseDirectory,
    );
    return results.isNotEmpty && results.first;
  }

  static void _collectStrings(dynamic val, Set<String> targetSet) {
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isNotEmpty) {
        targetSet.add(trimmed);
        if (trimmed.contains('/') || trimmed.contains('\\')) {
          try {
            targetSet.add(p.canonicalize(trimmed));
          } catch (_) {}
        }
      }
    } else if (val is Map) {
      for (final v in val.values) {
        _collectStrings(v, targetSet);
      }
    } else if (val is Iterable) {
      for (final item in val) {
        _collectStrings(item, targetSet);
      }
    }
  }
}
