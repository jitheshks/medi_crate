import 'package:flutter/foundation.dart';
import '../../../../core/utils/id_utils.dart';

/// Represents a single file attachment for a medical report.
@immutable
class ReportAttachmentModel {
  final String id;
  final String name;
  final String size;
  final int? sizeBytes;
  final String? filePath;
  final String? fileType;
  final String? fileUrl;

  const ReportAttachmentModel({
    required this.id,
    required this.name,
    required this.size,
    this.sizeBytes,
    this.filePath,
    this.fileType,
    this.fileUrl,
  });

  /// Helper to format byte counts into human-readable strings (e.g. 184320 -> "180 KB").
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.round()} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Returns true if the attachment is a PDF document based on name or MIME type.
  bool get isPdf {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf') ||
        (fileType?.toLowerCase().contains('pdf') ?? false);
  }

  /// Returns true if the attachment is an image based on name or MIME type.
  bool get isImage {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        (fileType?.toLowerCase().startsWith('image/') ?? false);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    if (sizeBytes != null) 'size_bytes': sizeBytes,
    if (filePath != null) 'file_path': filePath,
    if (fileType != null) 'file_type': fileType,
    if (fileUrl != null) 'file_url': fileUrl,
  };

  factory ReportAttachmentModel.fromJson(Map<String, dynamic> json) {
    final rawSize = json['size'] ?? json['size_bytes'] ?? json['sizeBytes'];
    int? bytes;
    String formattedSize = '0 KB';

    if (rawSize is num) {
      bytes = rawSize.toInt();
      formattedSize = formatBytes(bytes);
    } else if (rawSize is String) {
      formattedSize = rawSize;
      final digits = int.tryParse(rawSize.replaceAll(RegExp(r'[^0-9]'), ''));
      if (digits != null) {
        if (rawSize.toUpperCase().contains('MB')) {
          bytes = digits * 1024 * 1024;
        } else if (rawSize.toUpperCase().contains('KB')) {
          bytes = digits * 1024;
        } else {
          bytes = digits;
        }
      }
    }

    final rawBytes = json['size_bytes'] ?? json['sizeBytes'];
    if (rawBytes is num) {
      bytes = rawBytes.toInt();
    }

    return ReportAttachmentModel(
      id: json['id']?.toString() ?? '',
      name:
          json['name'] as String? ??
          json['filename'] as String? ??
          'attachment.pdf',
      size: formattedSize,
      sizeBytes: bytes,
      filePath: json['file_path'] as String? ?? json['filePath'] as String?,
      fileType: json['file_type'] as String? ?? json['fileType'] as String?,
      fileUrl: json['file_url'] as String? ?? json['fileUrl'] as String?,
    );
  }

  ReportAttachmentModel copyWith({
    String? id,
    String? name,
    String? size,
    int? sizeBytes,
    String? filePath,
    String? fileType,
    String? fileUrl,
  }) {
    return ReportAttachmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileUrl: fileUrl ?? this.fileUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportAttachmentModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          filePath == other.filePath &&
          fileUrl == other.fileUrl;

  @override
  int get hashCode => Object.hash(id, name, filePath, fileUrl);
}

/// Represents expense data associated with a medical report.
@immutable
class ReportExpenseModel {
  final String id;
  final double amount;
  final String currency;
  final String status; // 'PAID', 'PENDING', 'INSURANCE', 'REIMBURSED'
  final String? description;

  const ReportExpenseModel({
    required this.id,
    required this.amount,
    this.currency = 'INR',
    this.status = 'PAID',
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'currency': currency,
    'status': status,
    if (description != null) 'description': description,
  };

  factory ReportExpenseModel.fromJson(Map<String, dynamic> json) {
    return ReportExpenseModel(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      status: (json['status']?.toString() ?? 'PAID').toUpperCase(),
      description: json['description']?.toString(),
    );
  }

  ReportExpenseModel copyWith({
    String? id,
    double? amount,
    String? currency,
    String? status,
    String? description,
  }) {
    return ReportExpenseModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      description: description ?? this.description,
    );
  }
}

/// Core domain model for medical reports, lab results, prescriptions, and diagnostic documents.
@immutable
class ReportModel {
  final String id;
  final String profileId;
  final String title;
  final String
  category; // 'LAB TEST', 'IMAGING', 'PRESCRIPTION', 'DISCHARGE', 'CERTIFICATE', 'VACCINATION', 'REFERRAL', 'OTHER'
  final DateTime date;
  final String? doctorId;
  final String? doctorName;
  final String? hospitalId;
  final String? hospitalName;
  final String? consultationId;
  final String? consultationTitle;
  final String? notes;
  final List<ReportAttachmentModel> attachments;
  final ReportExpenseModel? expense;
  final String? clientUuid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReportModel({
    required this.id,
    required this.profileId,
    required this.title,
    required this.category,
    required this.date,
    this.doctorId,
    this.doctorName,
    this.hospitalId,
    this.hospitalName,
    this.consultationId,
    this.consultationTitle,
    this.notes,
    this.attachments = const [],
    this.expense,
    this.clientUuid,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile_id': profileId,
    'title': title,
    'category': category,
    'date': date.toIso8601String(),
    'doctor_id': doctorId,
    'doctor_name': doctorName,
    'hospital_id': hospitalId,
    'hospital_name': hospitalName,
    'consultation_id': consultationId,
    'consultation_title': consultationTitle,
    'notes': notes,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'expense': expense?.toJson(),
    if (clientUuid != null) 'client_uuid': clientUuid,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// Clean server metadata representation for Laravel Sanctum REST API.
  /// Omits device-local file paths to prepare for multipart boundary separation.
  Map<String, dynamic> toServerMetadataJson() {
    final cleanProfileId =
        IdUtils.toServerIntId(profileId) ??
        int.tryParse(IdUtils.unprefix(profileId)) ??
        profileId;
    final cleanDoctorId = IdUtils.toServerIntId(doctorId);
    final cleanHospitalId = IdUtils.toServerIntId(hospitalId);
    final cleanConsultationId = IdUtils.toServerIntId(consultationId);

    final normalizedCategory = normalizeCategoryToApi(category);
    final expStatus = expense?.status.toLowerCase();

    return {
      'profile_id': cleanProfileId,
      'title': title,
      'category': normalizedCategory,
      'date': date.toIso8601String().split('T').first,
      'doctor_id': ?cleanDoctorId,
      if (doctorName != null && doctorName!.trim().isNotEmpty)
        'doctor_name': doctorName!.trim(),
      'hospital_id': ?cleanHospitalId,
      if (hospitalName != null && hospitalName!.trim().isNotEmpty)
        'hospital_name': hospitalName!.trim(),
      'consultation_id': ?cleanConsultationId,
      if (consultationTitle != null && consultationTitle!.trim().isNotEmpty)
        'consultation_title': consultationTitle!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (expense != null) ...{
        'expense_amount': expense!.amount,
        'expense_status': ?expStatus,
        'expense_currency': expense!.currency,
      },
      if (clientUuid != null && clientUuid!.trim().isNotEmpty)
        'client_uuid': clientUuid!.trim(),
    };
  }

  /// Alias for toServerMetadataJson() matching cross-module API serialization convention.
  Map<String, dynamic> toApiJson() => toServerMetadataJson();

  static String normalizeCategoryToApi(String rawCategory) {
    final cat = rawCategory.trim().toUpperCase();
    switch (cat) {
      case 'LAB TEST':
      case 'LAB_TEST':
      case 'LABTEST':
        return 'Lab Test';
      case 'IMAGING':
      case 'IMAGING / RADIOLOGY':
        return 'Imaging';
      case 'PRESCRIPTION':
        return 'Prescription';
      case 'DISCHARGE':
      case 'DISCHARGE SUMMARY':
        return 'Discharge';
      case 'CERTIFICATE':
      case 'MEDICAL CERTIFICATE':
        return 'Certificate';
      case 'VACCINATION':
      case 'VACCINE':
        return 'Vaccination';
      case 'REFERRAL':
      case 'REFERRAL LETTER':
        return 'Referral';
      case 'OTHER':
      case 'OTHERS':
      default:
        return 'Other';
    }
  }

  static String normalizeCategoryToLocal(String rawCategory) {
    final cat = rawCategory.trim().toUpperCase();
    switch (cat) {
      case 'LAB TEST':
      case 'LAB_TEST':
      case 'LABTEST':
        return 'LAB TEST';
      case 'IMAGING':
      case 'IMAGING / RADIOLOGY':
        return 'IMAGING';
      case 'PRESCRIPTION':
        return 'PRESCRIPTION';
      case 'DISCHARGE':
      case 'DISCHARGE SUMMARY':
        return 'DISCHARGE';
      case 'CERTIFICATE':
      case 'MEDICAL CERTIFICATE':
        return 'CERTIFICATE';
      case 'VACCINATION':
      case 'VACCINE':
        return 'VACCINATION';
      case 'REFERRAL':
      case 'REFERRAL LETTER':
        return 'REFERRAL';
      case 'OTHER':
      case 'OTHERS':
      default:
        return 'OTHER';
    }
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final cUuid =
        json['client_uuid']?.toString() ?? json['clientUuid']?.toString();

    return ReportModel(
      id: json['id']?.toString() ?? '',
      profileId:
          json['profile_id']?.toString() ?? json['profileId']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      category: normalizeCategoryToLocal(
        json['category'] as String? ??
            json['report_type'] as String? ??
            'LAB TEST',
      ),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      doctorId: json['doctor_id']?.toString() ?? json['doctorId']?.toString(),
      doctorName:
          json['doctor_name'] as String? ??
          json['doctor'] as String? ??
          json['provider'] as String?,
      hospitalId:
          json['hospital_id']?.toString() ?? json['hospitalId']?.toString(),
      hospitalName:
          json['hospital_name'] as String? ??
          json['hospital'] as String? ??
          json['provider'] as String?,
      consultationId:
          json['consultation_id']?.toString() ??
          json['consultationId']?.toString(),
      consultationTitle:
          json['consultation_title'] as String? ??
          json['consultationTitle'] as String?,
      notes: json['notes'] as String?,
      attachments: json['attachments'] is List
          ? (json['attachments'] as List)
                .map(
                  (a) => ReportAttachmentModel.fromJson(
                    Map<String, dynamic>.from(a as Map),
                  ),
                )
                .toList()
          : [],
      expense: json['expense'] is Map
          ? ReportExpenseModel.fromJson(
              Map<String, dynamic>.from(json['expense'] as Map),
            )
          : (json['expense_amount'] != null
                ? ReportExpenseModel(
                    id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
                    amount: (json['expense_amount'] as num?)?.toDouble() ?? 0.0,
                    status: (json['expense_status']?.toString() ?? 'PAID')
                        .toUpperCase(),
                    currency: json['expense_currency']?.toString() ?? 'INR',
                  )
                : null),
      clientUuid: cUuid,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  ReportModel copyWith({
    String? id,
    String? profileId,
    String? title,
    String? category,
    DateTime? date,
    String? doctorId,
    String? doctorName,
    String? hospitalId,
    String? hospitalName,
    String? consultationId,
    String? consultationTitle,
    String? notes,
    List<ReportAttachmentModel>? attachments,
    ReportExpenseModel? expense,
    String? clientUuid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      hospitalId: hospitalId ?? this.hospitalId,
      hospitalName: hospitalName ?? this.hospitalName,
      consultationId: consultationId ?? this.consultationId,
      consultationTitle: consultationTitle ?? this.consultationTitle,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      expense: expense ?? this.expense,
      clientUuid: clientUuid ?? this.clientUuid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
