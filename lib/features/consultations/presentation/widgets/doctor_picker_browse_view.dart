import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../doctors/presentation/providers/doctors_providers.dart';

/// DoctorPickerBrowseView presents the searchable list of existing doctors
/// and the action to switch to the "Add New Doctor" creation flow.
class DoctorPickerBrowseView extends ConsumerStatefulWidget {
  final String? currentDoctorId;
  final String? currentDoctorName;
  final ValueChanged<DoctorModel> onDoctorSelected;
  final VoidCallback onAddNewRequested;

  const DoctorPickerBrowseView({
    super.key,
    this.currentDoctorId,
    this.currentDoctorName,
    required this.onDoctorSelected,
    required this.onAddNewRequested,
  });

  @override
  ConsumerState<DoctorPickerBrowseView> createState() =>
      _DoctorPickerBrowseViewState();
}

class _DoctorPickerBrowseViewState
    extends ConsumerState<DoctorPickerBrowseView> {
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
    final colorScheme = theme.colorScheme;
    final doctorsAsync = ref.watch(doctorsListProvider);
    final allDoctors = doctorsAsync.value ?? <DoctorModel>[];

    final filteredDoctors = allDoctors.where((doc) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatch = doc.name.toLowerCase().contains(q);
      final specMatch = doc.specialty.toLowerCase().contains(q);
      return nameMatch || specMatch;
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        AppSearchField(
          controller: _searchController,
          hintText: 'Search doctor or specialty...',
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
        const SizedBox(height: 12),

        // Action row: + Add New Doctor
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, color: colorScheme.primary, size: 20),
          ),
          title: Text(
            '+ Add New Doctor',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          onTap: widget.onAddNewRequested,
        ),
        Divider(height: 1, color: theme.dividerColor),
        const SizedBox(height: 8),

        // List / States
        if (doctorsAsync.isLoading && allDoctors.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredDoctors.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No doctors found.',
                style: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * 0.42)
                  .clamp(160.0, 320.0),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filteredDoctors.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: theme.dividerColor),
              itemBuilder: (context, index) {
                final doc = filteredDoctors[index];
                final isSelected =
                    (widget.currentDoctorId != null &&
                        widget.currentDoctorId!.isNotEmpty &&
                        IdUtils.matches(doc.id, widget.currentDoctorId)) ||
                    (widget.currentDoctorName != null &&
                        widget.currentDoctorName!.isNotEmpty &&
                        doc.name.trim().toLowerCase() ==
                            widget.currentDoctorName!.trim().toLowerCase());

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  title: Text(
                    doc.name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    doc.specialty,
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: colorScheme.primary,
                          size: 22,
                        )
                      : Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                  onTap: () {
                    widget.onDoctorSelected(doc);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
