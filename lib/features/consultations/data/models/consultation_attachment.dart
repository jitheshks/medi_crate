import 'package:flutter/foundation.dart';

import '../../../../core/utils/id_utils.dart';

/// Represents a file attachment (prescription, photo, lab report, PDF) associated with a consultation.
@immutable
class ConsultationAttachment {
  final String id;
  final String name;
  final int sizeKB;
  final String? filePath;
  final String? fileType;
  final String? fileUrl;

  const ConsultationAttachment({
    required this.id,
    required this.name,
    required this.sizeKB,
    this.filePath,
    this.fileType,
    this.fileUrl,
  });

  /// Returns true if the attachment is an image based on its extension.
  bool get isImage {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  /// Returns true if the attachment is a PDF document based on its extension.
  bool get isPdf {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf');
  }

  /// Formatted size string (e.g. "340 KB" or "2,450 KB").
  String get formattedSize {
    final kb = sizeKB > 0 ? sizeKB : 1;
    if (kb >= 1000) {
      final str = kb.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(str[i]);
      }
      return '${buffer.toString()} KB';
    }
    return '$kb KB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sizeKB': sizeKB,
    if (filePath != null) 'file_path': filePath,
    if (fileType != null) 'file_type': fileType,
    if (fileUrl != null) 'file_url': fileUrl,
  };

  /// Serializes attachment for public.consultation_attachments table in Supabase.
  Map<String, dynamic> toSupabaseJson({
    required String consultationId,
    required String userId,
    bool includeId = true,
  }) {
    final cleanId = IdUtils.unprefix(id).trim();
    final cleanConsultationId = IdUtils.unprefix(consultationId).trim();
    final cleanUserId = userId.trim();

    String remotePath = '';
    if (fileUrl != null &&
        fileUrl!.isNotEmpty &&
        !fileUrl!.startsWith('/') &&
        !fileUrl!.startsWith('file:')) {
      remotePath = fileUrl!.trim();
    } else if (filePath != null &&
        filePath!.isNotEmpty &&
        !filePath!.startsWith('/') &&
        !filePath!.startsWith('file:')) {
      remotePath = filePath!.trim();
    } else {
      remotePath = fileUrl?.trim() ?? filePath?.trim() ?? '';
    }

    return {
      if (includeId && UuidUtils.isValidUuid(cleanId)) 'id': cleanId,
      'consultation_id': cleanConsultationId,
      'user_id': cleanUserId,
      'name': name.trim(),
      'file_path': remotePath,
      if (fileType != null && fileType!.trim().isNotEmpty)
        'file_type': fileType!.trim(),
      'size_bytes': (sizeKB > 0 ? sizeKB : 1) * 1024,
    };
  }

  /// Deserializes a record from public.consultation_attachments PostgREST response.
  factory ConsultationAttachment.fromSupabaseJson(Map<String, dynamic> json) {
    final rawBytes = json['size_bytes'] ?? json['sizeBytes'];
    int size = 1;
    if (rawBytes is num) {
      size = (rawBytes / 1024).round();
      if (size < 1) size = 1;
    }

    return ConsultationAttachment(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'attachment',
      sizeKB: size,
      filePath: json['file_path']?.toString() ?? json['filePath']?.toString(),
      fileType: json['file_type']?.toString() ?? json['fileType']?.toString(),
      fileUrl: json['file_url']?.toString() ?? json['fileUrl']?.toString(),
    );
  }

  factory ConsultationAttachment.fromJson(Map<String, dynamic> json) {
    final rawSize =
        json['sizeKB'] ??
        json['size_kb'] ??
        json['file_size'] ??
        json['fileSize'] ??
        json['size'];
    int size = 1;
    if (rawSize is num) {
      final val = rawSize.toInt();
      size = val > 5000 ? (val / 1024).round() : val;
    } else if (rawSize is String) {
      final parsed = int.tryParse(rawSize.replaceAll(RegExp(r'[^0-9]'), ''));
      if (parsed != null && parsed > 0) {
        size = parsed > 5000 ? (parsed / 1024).round() : parsed;
      }
    }

    return ConsultationAttachment(
      id: json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ??
          json['file_name']?.toString() ??
          json['fileName']?.toString() ??
          json['filename']?.toString() ??
          'attachment',
      sizeKB: size > 0 ? size : 1,
      filePath: json['file_path']?.toString() ?? json['filePath']?.toString(),
      fileType: json['file_type']?.toString() ?? json['fileType']?.toString(),
      fileUrl:
          json['file_url']?.toString() ??
          json['fileUrl']?.toString() ??
          json['url']?.toString(),
    );
  }

  ConsultationAttachment copyWith({
    String? id,
    String? name,
    int? sizeKB,
    String? filePath,
    String? fileType,
    String? fileUrl,
  }) {
    return ConsultationAttachment(
      id: id ?? this.id,
      name: name ?? this.name,
      sizeKB: sizeKB ?? this.sizeKB,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileUrl: fileUrl ?? this.fileUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsultationAttachment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
