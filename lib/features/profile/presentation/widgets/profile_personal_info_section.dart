import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/forms/custom_text_field.dart';

class ProfilePersonalInfoSection extends StatelessWidget {
  final TextEditingController nameController;
  final DateTime? selectedDob;
  final String? selectedGender;
  final VoidCallback onPickDob;
  final ValueChanged<String?> onGenderChanged;

  static const List<String> genderOptions = ['Male', 'Female', 'Others'];

  const ProfilePersonalInfoSection({
    super.key,
    required this.nameController,
    required this.selectedDob,
    required this.selectedGender,
    required this.onPickDob,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = selectedDob != null
        ? DateFormat('MMMM d, yyyy').format(selectedDob!)
        : 'Select Date of Birth';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          label: 'FULL NAME',
          hint: 'e.g. Asha Menon',
          controller: nameController,
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Full name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        Text(
          'DATE OF BIRTH',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPickDob,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    style: AppTypography.bodyMedium.copyWith(
                      color: selectedDob != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: 20),
        Text(
          'GENDER (OPTIONAL)',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: genderOptions.map((gender) {
            final isSelected = selectedGender == gender;
            final reduceMotion = MediaQuery.of(context).disableAnimations;
            final duration = reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180);

            return ChoiceChip(
              label: AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeInOut,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                child: Text(gender),
              ),
              selected: isSelected,
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              side: BorderSide(
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
              onSelected: (selected) {
                onGenderChanged(selected ? gender : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
