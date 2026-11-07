import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../../data/models/medical_department_model.dart';
import '../providers/medical_department_providers.dart';

/// Modal bottom sheet for selecting a Medical Department from the backend reference list (MD1).
///
/// NOTE: The backend API provides a fixed reference list with NO create/add department endpoint.
/// Therefore, this picker strictly displays available departments without any "+ Add Department" action.
class MedicalDepartmentPickerSheet extends ConsumerStatefulWidget {
  final int? currentDepartmentId;
  final String? currentDepartmentName;
  final ValueChanged<MedicalDepartmentModel> onSelected;

  const MedicalDepartmentPickerSheet({
    super.key,
    this.currentDepartmentId,
    this.currentDepartmentName,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    int? currentDepartmentId,
    String? currentDepartmentName,
    required ValueChanged<MedicalDepartmentModel> onSelected,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) {
        return MedicalDepartmentPickerSheet(
          currentDepartmentId: currentDepartmentId,
          currentDepartmentName: currentDepartmentName,
          onSelected: onSelected,
        );
      },
    );
  }

  @override
  ConsumerState<MedicalDepartmentPickerSheet> createState() =>
      _MedicalDepartmentPickerSheetState();
}

class _MedicalDepartmentPickerSheetState
    extends ConsumerState<MedicalDepartmentPickerSheet> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departmentsAsync = ref.watch(medicalDepartmentsProvider);

    return AppBottomSheet(
      title: 'Select Medical Department',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          AppSearchField(
            controller: _searchController,
            hintText: 'Search clinical department...',
            onChanged: (val) =>
                setState(() => _searchQuery = val.trim().toLowerCase()),
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
          const SizedBox(height: 16),

          // Content List / States
          departmentsAsync.when(
            data: (departments) {
              final q = _searchQuery;
              final filtered = q.isEmpty
                  ? departments
                  : departments.where((d) {
                      return d.name.toLowerCase().contains(q);
                    }).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: _searchQuery.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.search_off_rounded,
                          showIconContainer: false,
                          title: 'No medical departments available.',
                        )
                      : AppEmptyState.filtered(
                          title: 'No matching department found.',
                          message: null,
                          actionLabel: 'Clear Search',
                          actionIcon: null,
                          onAction: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                );
              }

              return SizedBox(
                height: 320,
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (context, index) {
                    final dept = filtered[index];
                    final isSelected =
                        (widget.currentDepartmentId != null &&
                            widget.currentDepartmentId == dept.id) ||
                        (widget.currentDepartmentName != null &&
                            widget.currentDepartmentName!
                                    .trim()
                                    .toUpperCase() ==
                                dept.name.trim().toUpperCase());

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      title: Text(
                        dept.name,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                              size: 22,
                            )
                          : Icon(
                              Icons.circle_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                      onTap: () {
                        widget.onSelected(dept);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: PulsingVaultLogo()),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 36,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load medical departments.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please check your network connection and retry.',
                      style: AppTypography.caption.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(medicalDepartmentsProvider),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
