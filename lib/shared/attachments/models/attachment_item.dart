import 'dart:io';

import '../../../../features/consultations/data/models/consultation_attachment.dart';
import '../../../../features/reports/data/models/report_model.dart';

/// Unified immutable model representing a file attachment across any MediCrate module
/// (Reports, Consultations, Prescriptions, etc.).
class AttachmentItem {
  final String id;
  final String name;
  final String? filePath;
  final String? fileType;
  final String? fileUrl;
  final String formattedSize;
  final int? sizeBytes;

  const AttachmentItem({
    required this.id,
    required this.name,
    this.filePath,
    this.fileType,
    this.fileUrl,
    required this.formattedSize,
    this.sizeBytes,
  });

  /// True if the attachment is a PDF document based on name or MIME type.
  bool get isPdf {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf') ||
        (fileType?.toLowerCase().contains('pdf') ?? false);
  }

  /// True if the attachment is an image based on name or MIME type.
  bool get isImage {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        (fileType?.toLowerCase().startsWith('image/') ?? false);
  }

  /// True if a verified physical file exists on the local filesystem.
  bool get isLocalAvailable {
    if (filePath == null || filePath!.trim().isEmpty) return false;
    try {
      return File(filePath!).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Returns the file extension in lowercase without leading dot, or 'bin' fallback.
  String get fileExtension {
    if (name.contains('.')) {
      final ext = name.split('.').last.trim().toLowerCase();
      if (ext.isNotEmpty) return ext;
    }
    if (isPdf) return 'pdf';
    if (isImage) {
      if (fileType != null && fileType!.contains('/')) {
        return fileType!.split('/').last.toLowerCase();
      }
      return 'jpg';
    }
    return 'bin';
  }

  /// Creates an [AttachmentItem] adapter from a [ReportAttachmentModel].
  factory AttachmentItem.fromReportAttachment(ReportAttachmentModel model) {
    return AttachmentItem(
      id: model.id,
      name: model.name,
      filePath: model.filePath,
      fileType: model.fileType,
      fileUrl: model.fileUrl,
      formattedSize: model.size,
      sizeBytes: model.sizeBytes,
    );
  }

  /// Creates an [AttachmentItem] adapter from a [ConsultationAttachment].
  factory AttachmentItem.fromConsultationAttachment(
    ConsultationAttachment model,
  ) {
    return AttachmentItem(
      id: model.id,
      name: model.name,
      filePath: model.filePath,
      fileType: model.fileType,
      fileUrl: model.fileUrl,
      formattedSize: model.formattedSize,
      sizeBytes: model.sizeKB > 0 ? model.sizeKB * 1024 : null,
    );
  }

  AttachmentItem copyWith({
    String? id,
    String? name,
    String? filePath,
    String? fileType,
    String? fileUrl,
    String? formattedSize,
    int? sizeBytes,
  }) {
    return AttachmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileUrl: fileUrl ?? this.fileUrl,
      formattedSize: formattedSize ?? this.formattedSize,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          filePath == other.filePath &&
          fileUrl == other.fileUrl;

  @override
  int get hashCode => Object.hash(id, name, filePath, fileUrl);
}
