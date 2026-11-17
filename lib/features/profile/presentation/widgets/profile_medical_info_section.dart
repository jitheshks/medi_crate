import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/forms/custom_text_field.dart';

class ProfileMedicalInfoSection extends StatelessWidget {
  final String? selectedBloodGroup;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final ValueChanged<String?> onBloodGroupChanged;

  static const List<String> bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  const ProfileMedicalInfoSection({
    super.key,
    required this.selectedBloodGroup,
    required this.heightController,
    required this.weightController,
    required this.onBloodGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BLOOD GROUP',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = ((constraints.maxWidth - 22) / 3).floorToDouble();
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: bloodGroupOptions.map((bg) {
                final isSelected = selectedBloodGroup == bg;
                return SizedBox(
                  width: cardWidth,
                  height: 44,
                  child: InkWell(
                    onTap: () {
                      onBloodGroupChanged(isSelected ? null : bg);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline,
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          bg,
                          style: TextStyle(
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn = constraints.maxWidth >= 280;
            if (isTwoColumn) {
              return Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'HEIGHT (CM)',
                      hint: 'e.g. 175',
                      controller: heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: CustomTextField(
                      label: 'WEIGHT (KG)',
                      hint: 'e.g. 70',
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                CustomTextField(
                  label: 'HEIGHT (CM)',
                  hint: 'e.g. 175',
                  controller: heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'WEIGHT (KG)',
                  hint: 'e.g. 70',
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
