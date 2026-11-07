import 'package:flutter/material.dart';

/// Common aggregated event model for the longitudinal health timeline.
@immutable
class TimelineEventModel {
  final String id;
  final String profileId;
  final String type; // 'consultation', 'appointment', 'measurement', 'medicine', 'report', 'expense', 'doctor', 'hospital'
  final String title;
  final String summary;
  final DateTime? eventDate;
  final String badgeText;
  final IconData icon;
  final Color color;
  final String targetRoute;
  final String targetId;
  final Map<String, dynamic>? metadata;

  const TimelineEventModel({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.summary,
    this.eventDate,
    required this.badgeText,
    required this.icon,
    required this.color,
    required this.targetRoute,
    required this.targetId,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'profile_id': profileId,
    'type': type,
    'title': title,
    'summary': summary,
    'event_date': eventDate?.toIso8601String(),
    'badge_text': badgeText,
    'target_route': targetRoute,
    'target_id': targetId,
    'metadata': metadata,
  };

  TimelineEventModel copyWith({
    String? id,
    String? profileId,
    String? type,
    String? title,
    String? summary,
    DateTime? eventDate,
    String? badgeText,
    IconData? icon,
    Color? color,
    String? targetRoute,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) {
    return TimelineEventModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      type: type ?? this.type,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      eventDate: eventDate ?? this.eventDate,
      badgeText: badgeText ?? this.badgeText,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      targetRoute: targetRoute ?? this.targetRoute,
      targetId: targetId ?? this.targetId,
      metadata: metadata ?? this.metadata,
    );
  }
}
