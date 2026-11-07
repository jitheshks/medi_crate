import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';
import '../../../hospitals/data/models/hospital_model.dart';
import '../../../hospitals/presentation/providers/hospitals_providers.dart';

/// HospitalPickerBrowseView presents the searchable list of existing hospitals
/// and the action to switch to the "Add New Hospital" creation flow.
class HospitalPickerBrowseView extends ConsumerStatefulWidget {
  final String? currentHospitalId;
  final String? currentHospitalName;
  final ValueChanged<HospitalModel> onHospitalSelected;
  final VoidCallback onAddNewRequested;

  const HospitalPickerBrowseView({
    super.key,
    this.currentHospitalId,
    this.currentHospitalName,
    required this.onHospitalSelected,
    required this.onAddNewRequested,
  });

  @override
  ConsumerState<HospitalPickerBrowseView> createState() =>
      _HospitalPickerBrowseViewState();
}

class _HospitalPickerBrowseViewState
    extends ConsumerState<HospitalPickerBrowseView> {
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
    final hospitalsAsync = ref.watch(hospitalsListProvider);
    final allHospitals = hospitalsAsync.value ?? <HospitalModel>[];

    final filteredHospitals = allHospitals.where((hosp) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatch = hosp.name.toLowerCase().contains(q);
      final typeMatch = (hosp.type ?? '').toLowerCase().contains(q);
      final addrMatch = (hosp.address ?? '').toLowerCase().contains(q);
      return nameMatch || typeMatch || addrMatch;
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        AppSearchField(
          controller: _searchController,
          hintText: 'Search hospital, clinic, or facility...',
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
        const SizedBox(height: 12),

        // Action row: + Add New Hospital
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
            '+ Add New Hospital / Clinic',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          onTap: widget.onAddNewRequested,
        ),
        Divider(height: 1, color: colorScheme.outline),
        const SizedBox(height: 8),

        // List / States
        if (hospitalsAsync.isLoading && allHospitals.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filteredHospitals.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'No matching hospital or clinic found.'
                    : 'No hospitals added yet.',
                style: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.separated(
              itemCount: filteredHospitals.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: colorScheme.outline),
              itemBuilder: (context, index) {
                final hosp = filteredHospitals[index];
                final isSelected =
                    (widget.currentHospitalId != null &&
                        widget.currentHospitalId!.isNotEmpty &&
                        IdUtils.matches(hosp.id, widget.currentHospitalId)) ||
                    (widget.currentHospitalName != null &&
                        widget.currentHospitalName!.isNotEmpty &&
                        hosp.name.trim().toLowerCase() ==
                            widget.currentHospitalName!.trim().toLowerCase());

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.hospital,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    hosp.name,
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
                    hosp.type ?? 'Hospital',
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
                    widget.onHospitalSelected(hosp);
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
