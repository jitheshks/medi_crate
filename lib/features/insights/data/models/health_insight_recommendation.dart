import 'package:flutter/material.dart';

/// HealthInsightRecommendation represents an actionable, profile-scoped health recommendation
/// derived from observable application health records.
class HealthInsightRecommendation {
  final String id;
  final String title;
  final String description;
  final String actionLabel;
  final String targetRoute;
  final IconData icon;

  const HealthInsightRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.targetRoute,
    required this.icon,
  });
}
