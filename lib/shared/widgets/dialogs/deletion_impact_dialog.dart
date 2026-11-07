import 'package:flutter/material.dart';
import 'package:medi_crate/core/constants/app_typography.dart';
import 'package:medi_crate/core/theme/app_theme.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_hospital_relation.dart';

import 'deletion_dialog_variants.dart';

/// Classification of deletion impact for legacy/profile callers.
enum DeletionImpactType {
  /// Record is preserved, but the foreign key / relationship link to the deleted entity is removed.
  relationshipRemoved,

  /// Record remains completely untouched and accessible.
  recordKept,

  /// Record will be permanently cascaded / deleted along with parent.
  recordDeleted,
}

/// Represents a single linked-record impact category with dynamic count for legacy callers.
class DeletionImpactItem {
  final int count;
  final String label;
  final String description;
  final DeletionImpactType type;

  const DeletionImpactItem({
    required this.count,
    required this.label,
    required this.description,
    this.type = DeletionImpactType.relationshipRemoved,
  });
}

/// Standardized dependency-aware deletion dialog enforcing validated relational UX.
class DeletionImpactDialog extends StatelessWidget {
  final String title;
  final String recordName;
  final String recordType;
  final EntityDependencies dependencies;
  final List<DeletionImpactItem> impactItems;
  final String? explanatoryMessage;
  final String? customWarning;
  final VoidCallback? onConfirm;
  final VoidCallback? onViewLinkedRecords;
  final String deleteButtonText;
  final bool isReassuranceOnly;
  final String? reassuranceMessage;
  final bool isLegacyMode;

  const DeletionImpactDialog({
    super.key,
    required this.title,
    required this.recordName,
    required this.recordType,
    this.dependencies = const EntityDependencies(),
    this.impactItems = const [],
    this.explanatoryMessage,
    this.customWarning,
    this.onConfirm,
    this.onViewLinkedRecords,
    this.deleteButtonText = 'DELETE',
    this.isReassuranceOnly = false,
    this.reassuranceMessage,
    this.isLegacyMode = false,
  });

  static DateTime _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 500);

  /// Shows dependency-aware deletion dialog for Doctor, Hospital, or Consultation.
  static Future<bool?> showDependencyAware(
    BuildContext context, {
    required String recordName,
    required String recordType,
    required EntityDependencies dependencies,
    String? explanatoryMessage,
    VoidCallback? onConfirm,
    VoidCallback? onViewLinkedRecords,
  }) async {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) return null;
    _lastOpenTime = now;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => DeletionImpactDialog(
        title: 'Delete $recordName?',
        recordName: recordName,
        recordType: recordType,
        dependencies: dependencies,
        explanatoryMessage: explanatoryMessage,
        onConfirm: onConfirm,
        onViewLinkedRecords: onViewLinkedRecords,
      ),
    );
  }

  /// Shows reassurance deletion dialog for Report or Medicine.
  static Future<bool?> showReassuranceDelete(
    BuildContext context, {
    required String title,
    required String recordName,
    required String recordType,
    required String reassuranceMessage,
    required VoidCallback onConfirm,
  }) async {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) return null;
    _lastOpenTime = now;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => DeletionImpactDialog(
        title: title,
        recordName: recordName,
        recordType: recordType,
        isReassuranceOnly: true,
        reassuranceMessage: reassuranceMessage,
        onConfirm: onConfirm,
      ),
    );
  }

  /// Backward-compatible show method for profile deletion or legacy caller usage.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String recordName,
    required String recordType,
    required List<DeletionImpactItem> impactItems,
    String? customWarning,
    required VoidCallback onConfirm,
    String deleteButtonText = 'DELETE',
  }) async {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) return null;
    _lastOpenTime = now;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => DeletionImpactDialog(
        title: title,
        recordName: recordName,
        recordType: recordType,
        impactItems: impactItems,
        customWarning: customWarning,
        onConfirm: onConfirm,
        deleteButtonText: deleteButtonText,
        isLegacyMode: true,
      ),
    );
  }

  /// Shows 409 RESOURCE_HAS_DEPENDENCIES conflict dialog when backend rejects deletion.
  static Future<void> show409Conflict(
    BuildContext context, {
    required String recordType,
    String? customMessage,
    VoidCallback? onViewLinkedRecords,
  }) async {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) return;
    _lastOpenTime = now;
    final lowerType = recordType.toLowerCase();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ctx.semanticColors.warningContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: ctx.semanticColors.statusWarning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cannot delete this $lowerType',
                  style: AppTypography.h2.copyWith(
                    fontSize: 18,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customMessage ??
                    'This $lowerType is still referenced by other records.\n\nRemove or reassign those records before trying to permanently delete this $lowerType.',
                style: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          actions: [
            if (onViewLinkedRecords != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onViewLinkedRecords();
                },
                child: const Text('VIEW LINKED RECORDS'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  @visibleForTesting
  static void reset() {
    _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    if (isLegacyMode) {
      return LegacyDeletionDialog(
        title: title,
        recordName: recordName,
        impactItems: impactItems,
        customWarning: customWarning,
        deleteButtonText: deleteButtonText,
        onConfirm: onConfirm,
      );
    }

    if (isReassuranceOnly) {
      return ReassuranceDeletionDialog(
        title: title,
        reassuranceMessage: reassuranceMessage,
        deleteButtonText: deleteButtonText,
        onConfirm: onConfirm,
      );
    }

    if (dependencies.hasDependencies) {
      return BlockedDeletionDialog(
        title: title,
        recordType: recordType,
        dependencies: dependencies,
        explanatoryMessage: explanatoryMessage,
        onViewLinkedRecords: onViewLinkedRecords,
      );
    }

    return AllowedDeletionDialog(
      title: title,
      recordType: recordType,
      deleteButtonText: deleteButtonText,
      onConfirm: onConfirm,
    );
  }
}
