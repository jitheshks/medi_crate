import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../consultation_section_header.dart';

class ConsultationClinicalSection extends StatelessWidget {
  final TextEditingController chiefComplaintController;
  final TextEditingController diagnosisController;
  final TextEditingController clinicalNotesController;

  const ConsultationClinicalSection({
    super.key,
    required this.chiefComplaintController,
    required this.diagnosisController,
    required this.clinicalNotesController,
  });

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String hintText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3. CHIEF COMPLAINT SECTION
        const ConsultationSectionHeader(label: 'Chief Complaint *'),
        TextFormField(
          controller: chiefComplaintController,
          maxLines: 3,
          style: TextStyle(color: colorScheme.onSurface),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter chief complaint / reason for visit';
            }
            return null;
          },
          decoration: _buildInputDecoration(
            context,
            hintText:
                'Chest pain, fever, persistent headache, routine checkup...',
          ),
        ),
        const SizedBox(height: 20),

        // 4. DIAGNOSIS SECTION
        const ConsultationSectionHeader(label: 'Diagnosis *'),
        TextFormField(
          controller: diagnosisController,
          maxLines: 2,
          style: TextStyle(color: colorScheme.onSurface),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter diagnosis';
            }
            return null;
          },
          decoration: _buildInputDecoration(
            context,
            hintText: 'Essential Hypertension, Stage 1 / Migraine / Asthma...',
          ),
        ),
        const SizedBox(height: 20),

        // 5. CLINICAL NOTES SECTION
        const ConsultationSectionHeader(label: 'Clinical Notes'),
        TextFormField(
          controller: clinicalNotesController,
          maxLines: 4,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: _buildInputDecoration(
            context,
            hintText: 'Doctor observations, treatment plan, lifestyle modifications, prescriptions...',
          ),
        ),
      ],
    );
  }
}
