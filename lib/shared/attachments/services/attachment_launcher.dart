import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Result status when attempting to open a file with an external app.
enum OpenFileStatus {
  success,
  noAppToOpen,
  fileNotFound,
  permissionDenied,
  error,
}

/// Helper service to open, save, and share local attachment files safely.
class AttachmentLauncher {
  /// Opens a local file using the device's default application for that MIME type/extension.
  static Future<({OpenFileStatus status, String message})> openFile(
    String filePath,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return (
        status: OpenFileStatus.fileNotFound,
        message: 'The file could not be found in local storage.',
      );
    }

    try {
      final result = await OpenFilex.open(filePath);
      switch (result.type) {
        case ResultType.done:
          return (
            status: OpenFileStatus.success,
            message: 'File opened successfully.',
          );
        case ResultType.noAppToOpen:
          return (
            status: OpenFileStatus.noAppToOpen,
            message: 'No compatible application installed to open this file.',
          );
        case ResultType.fileNotFound:
          return (
            status: OpenFileStatus.fileNotFound,
            message: 'The file could not be found.',
          );
        case ResultType.permissionDenied:
          return (
            status: OpenFileStatus.permissionDenied,
            message: 'Permission denied to open this file.',
          );
        case ResultType.error:
          return (
            status: OpenFileStatus.error,
            message: result.message.isNotEmpty
                ? result.message
                : 'Unable to open file.',
          );
      }
    } catch (e) {
      return (status: OpenFileStatus.error, message: 'Could not open file: $e');
    }
  }

  /// Shares a local file via the platform standard share sheet.
  static Future<bool> shareFile({
    required String filePath,
    String? mimeType,
    String? subject,
    String? text,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    try {
      final xFile = XFile(filePath, mimeType: mimeType);
      final result = await SharePlus.instance.share(
        ShareParams(files: [xFile], subject: subject, text: text),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  }

  /// Saves/copies the original attachment file to the platform-appropriate downloads
  /// or documents directory with name collision handling.
  static Future<({bool success, String? savedPath, String message})>
  saveAttachmentToDevice({
    required File localFile,
    required String fileName,
    Directory? targetDirectoryOverride,
  }) async {
    if (!localFile.existsSync()) {
      return (
        success: false,
        savedPath: null,
        message: 'Original file not found in cache.',
      );
    }

    try {
      Directory? targetDir = targetDirectoryOverride;

      if (targetDir == null) {
        if (Platform.isAndroid) {
          // Try standard Android public Download directory
          final publicDownload = Directory('/storage/emulated/0/Download');
          if (publicDownload.existsSync()) {
            targetDir = publicDownload;
          } else {
            final externalDirs = await getExternalStorageDirectories(
              type: StorageDirectory.downloads,
            );
            if (externalDirs != null && externalDirs.isNotEmpty) {
              targetDir = externalDirs.first;
            }
          }
        } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
          targetDir = await getDownloadsDirectory();
        }

        // Fallback for iOS or if download dir is unavailable
        targetDir ??= await getApplicationDocumentsDirectory();
      }

      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      // Sanitize base name and preserve extension
      final cleanBaseName = p.basenameWithoutExtension(fileName).trim().isEmpty
          ? 'attachment'
          : p.basenameWithoutExtension(fileName).trim();
      final ext = p.extension(fileName).isNotEmpty
          ? p.extension(fileName)
          : p.extension(localFile.path);

      String targetPath = p.join(targetDir.path, '$cleanBaseName$ext');
      int counter = 1;

      // Handle name collisions without overwriting existing files
      while (File(targetPath).existsSync()) {
        targetPath = p.join(targetDir.path, '$cleanBaseName ($counter)$ext');
        counter++;
      }

      final savedFile = await localFile.copy(targetPath);
      final finalName = p.basename(savedFile.path);

      return (
        success: true,
        savedPath: savedFile.path,
        message: 'Saved $finalName to ${p.basename(targetDir.path)}',
      );
    } catch (e) {
      return (
        success: false,
        savedPath: null,
        message: 'Failed to save file: $e',
      );
    }
  }
}
