import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';

class ProfileDemographicsInputSection extends StatelessWidget {
  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;
  final String? selectedBloodGroup;
  final ValueChanged<String?> onBloodGroupChanged;
  final DateTime? selectedDob;
  final VoidCallback onPickDob;

  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  const ProfileDemographicsInputSection({
    super.key,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.selectedBloodGroup,
    required this.onBloodGroupChanged,
    required this.selectedDob,
    required this.onPickDob,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn = constraints.maxWidth >= 330;
            if (isTwoColumn) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildGenderField(context, colorScheme)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildBloodGroupField(context, colorScheme)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGenderField(context, colorScheme),
                const SizedBox(height: 16),
                _buildBloodGroupField(context, colorScheme),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Date of Birth',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPickDob,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedDob != null
                        ? "${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}"
                        : 'Select Birth Date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: selectedDob != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  AppIcons.calendar,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderField(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedGender,
          isExpanded: true,
          hint: const Text('Select Gender', overflow: TextOverflow.ellipsis),
          decoration: InputDecoration(
            hintText: 'Select Gender',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Male',
              child: Text('Male', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'Female',
              child: Text('Female', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'Others',
              child: Text('Others', overflow: TextOverflow.ellipsis),
            ),
          ],
          onChanged: onGenderChanged,
        ),
      ],
    );
  }

  Widget _buildBloodGroupField(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Blood Group',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedBloodGroup,
          isExpanded: true,
          hint: const Text(
            'Select Blood Group',
            overflow: TextOverflow.ellipsis,
          ),
          decoration: InputDecoration(
            hintText: 'Select Blood Group',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
          ),
          items: bloodGroups
              .map(
                (bg) => DropdownMenuItem(
                  value: bg,
                  child: Text(bg, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onBloodGroupChanged,
        ),
      ],
    );
  }
}
