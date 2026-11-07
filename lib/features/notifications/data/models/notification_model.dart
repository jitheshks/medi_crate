import 'package:flutter/foundation.dart';

/// Supported notification categories in MediVault.
enum NotificationType { appointment, medicine, measurement, report }

/// NotificationModel represents a profile-scoped notification record in MediVault.
@immutable
class NotificationModel {
  final String id;
  final String profileId;
  final NotificationType type;
  final String title;
  final String description;
  final DateTime date;
  final bool isRead;
  final String? linkType;
  final String? linkId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NotificationModel({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.description,
    required this.date,
    this.isRead = false,
    this.linkType,
    this.linkId,
    this.createdAt,
    this.updatedAt,
  });

  NotificationModel copyWith({
    String? id,
    String? profileId,
    NotificationType? type,
    String? title,
    String? description,
    DateTime? date,
    bool? isRead,
    String? linkType,
    String? linkId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
      linkType: linkType ?? this.linkType,
      linkId: linkId ?? this.linkId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'type': type.name,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'is_read': isRead,
      'link_type': linkType,
      'link_id': linkId,
      'created_at': (createdAt ?? date).toIso8601String(),
      'updated_at': (updatedAt ?? date).toIso8601String(),
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Parse notification type safely
    final rawType = (json['type'] ?? 'appointment').toString().toLowerCase();
    NotificationType parsedType;
    switch (rawType) {
      case 'appointment':
        parsedType = NotificationType.appointment;
        break;
      case 'medicine':
      case 'medication':
        parsedType = NotificationType.medicine;
        break;
      case 'measurement':
      case 'measurements':
      case 'vital':
      case 'vitals':
        parsedType = NotificationType.measurement;
        break;
      case 'report':
      case 'reports':
        parsedType = NotificationType.report;
        break;
      default:
        parsedType = NotificationType.appointment;
    }

    DateTime parsedDate;
    if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? parsedCreatedAt;
    if (json['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['created_at'].toString());
    }

    DateTime? parsedUpdatedAt;
    if (json['updated_at'] != null) {
      parsedUpdatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    final isReadVal = json['is_read'] ?? json['isRead'] ?? false;
    final bool parsedIsRead = isReadVal is bool
        ? isReadVal
        : isReadVal.toString() == 'true';

    return NotificationModel(
      id: (json['id'] ?? '').toString(),
      profileId: (json['profile_id'] ?? json['profileId'] ?? '').toString(),
      type: parsedType,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      date: parsedDate,
      isRead: parsedIsRead,
      linkType: json['link_type']?.toString() ?? json['linkType']?.toString(),
      linkId: json['link_id']?.toString() ?? json['linkId']?.toString(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          profileId == other.profileId &&
          type == other.type &&
          title == other.title &&
          description == other.description &&
          date == other.date &&
          isRead == other.isRead &&
          linkType == other.linkType &&
          linkId == other.linkId;

  @override
  int get hashCode =>
      id.hashCode ^
      profileId.hashCode ^
      type.hashCode ^
      title.hashCode ^
      description.hashCode ^
      date.hashCode ^
      isRead.hashCode ^
      linkType.hashCode ^
      linkId.hashCode;

  @override
  String toString() =>
      'NotificationModel(id: $id, profileId: $profileId, type: ${type.name}, title: $title, isRead: $isRead, linkType: $linkType, linkId: $linkId)';
}
