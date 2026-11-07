import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/report_model.dart';

/// ReportAttachmentHelper manages persistent local file storage for medical report attachments.
///
/// Ensures selected files are copied from temporary picker caches into persistent,
/// app-controlled local profile directories so that background sync and offline
/// viewing survive app restarts and background isolate transitions.
class ReportAttachmentHelper {
  /// Resolves the dedicated persistent attachments directory for [profileId].
  static Future<Directory> getProfileAttachmentDirectory(
    String profileId, {
    String? clientUuid,
    Directory? customBaseDirectory,
  }) async {
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
    final path = clientUuid != null && clientUuid.trim().isNotEmpty
        ? '${appDir.path}/profiles/$profileId/reports/$clientUuid'
        : '${appDir.path}/profiles/$profileId/attachments';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies an arbitrary [sourceFile] into persistent profile-scoped storage.
  static Future<ReportAttachmentModel> saveFileToPersistentStorage({
    required File sourceFile,
    required String profileId,
    String? clientUuid,
    String? customFileName,
    Directory? customBaseDirectory,
  }) async {
    final targetDir = await getProfileAttachmentDirectory(
      profileId,
      clientUuid: clientUuid,
      customBaseDirectory: customBaseDirectory,
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final originalName =
        customFileName ?? sourceFile.path.split(Platform.pathSeparator).last;
    final ext = originalName.contains('.')
        ? originalName.split('.').last
        : 'dat';
    final targetPath = '${targetDir.path}/report_att_$timestamp.$ext';

    final savedFile = await sourceFile.copy(targetPath);
    final sizeInBytes = await savedFile.length();
    final mime = detectMimeType(ext);

    return ReportAttachmentModel(
      id: 'att_$timestamp',
      name: originalName.isNotEmpty
          ? originalName
          : 'attachment_$timestamp.$ext',
      size: ReportAttachmentModel.formatBytes(sizeInBytes),
      sizeBytes: sizeInBytes,
      filePath: targetPath,
      fileType: mime,
    );
  }

  /// Saves raw binary bytes (e.g. from R6 download) into persistent profile storage
  /// while strictly preserving the original attachment format and file extension.
  static Future<ReportAttachmentModel> saveBytesToPersistentStorage({
    required List<int> bytes,
    required String profileId,
    required String fileName,
    String? fileType,
    String? attachmentId,
    String? clientUuid,
    Directory? customBaseDirectory,
  }) async {
    final targetDir = await getProfileAttachmentDirectory(
      profileId,
      clientUuid: clientUuid,
      customBaseDirectory: customBaseDirectory,
    );

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String ext = 'dat';
    if (fileName.contains('.')) {
      ext = fileName.split('.').last.toLowerCase();
    } else if (fileType != null && fileType.trim().isNotEmpty) {
      final cleanMime = fileType.trim().toLowerCase();
      if (cleanMime.contains('pdf')) {
        ext = 'pdf';
      } else if (cleanMime.contains('jpeg') || cleanMime.contains('jpg')) {
        ext = 'jpg';
      } else if (cleanMime.contains('png')) {
        ext = 'png';
      } else if (cleanMime.contains('webp')) {
        ext = 'webp';
      }
    }

    final safeId = attachmentId != null && attachmentId.isNotEmpty
        ? attachmentId
        : 'att_$timestamp';
    final targetPath = '${targetDir.path}/report_att_${safeId}_$timestamp.$ext';

    final file = File(targetPath);
    await file.writeAsBytes(bytes);
    final sizeInBytes = bytes.length;
    final mime = fileType ?? detectMimeType(ext);

    return ReportAttachmentModel(
      id: safeId,
      name: fileName,
      size: ReportAttachmentModel.formatBytes(sizeInBytes),
      sizeBytes: sizeInBytes,
      filePath: targetPath,
      fileType: mime,
    );
  }

  /// Prompts image picker (gallery) and persists the selected file into profile storage.
  static Future<ReportAttachmentModel?> pickAndSaveAttachment({
    required String profileId,
    String? clientUuid,
    Directory? customBaseDirectory,
  }) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final sourceFile = File(image.path);
      return saveFileToPersistentStorage(
        sourceFile: sourceFile,
        profileId: profileId,
        clientUuid: clientUuid,
        customFileName: image.name.isNotEmpty ? image.name : null,
        customBaseDirectory: customBaseDirectory,
      );
    }
    return null;
  }

  /// Checks if the physical file for [attachment] exists in local storage.
  static bool verifyAttachmentFileExists(ReportAttachmentModel attachment) {
    if (attachment.filePath == null || attachment.filePath!.trim().isEmpty) {
      return false;
    }
    final file = File(attachment.filePath!);
    return file.existsSync();
  }

  /// Retrieves the [File] handle for [attachment] if present on disk.
  static File? getAttachmentFile(ReportAttachmentModel attachment) {
    if (attachment.filePath != null && attachment.filePath!.trim().isNotEmpty) {
      final file = File(attachment.filePath!);
      if (file.existsSync()) {
        return file;
      }
    }
    return null;
  }

  /// Safely deletes the physical attachment file from disk.
  static Future<void> deleteAttachmentFile(
    ReportAttachmentModel attachment,
  ) async {
    if (attachment.filePath != null && attachment.filePath!.trim().isNotEmpty) {
      try {
        final file = File(attachment.filePath!);
        if (file.path.contains('/profiles/') && await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Detects MIME type from file extension.
  static String detectMimeType(String ext) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    switch (cleanExt) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
