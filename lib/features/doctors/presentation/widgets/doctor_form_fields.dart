import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/doctor_model.dart';
import 'doctor_hospital_selection_section.dart';
import 'form/doctor_form_controller.dart';

class DoctorFormFields extends StatelessWidget {
  final DoctorFormController controller;
  final DoctorModel? originalDoctor;
  final VoidCallback onOpenHospitalPicker;
  final ValueChanged<String> onRemoveHospital;

  const DoctorFormFields({
    super.key,
    required this.controller,
    required this.originalDoctor,
    required this.onOpenHospitalPicker,
    required this.onRemoveHospital,
  });

  Widget _buildLabel(BuildContext context, String label) {
    return Text(
      label,
      style: AppTypography.caption.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, 'DOCTOR NAME *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Dr. Jane Doe',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (val) => Validators.validateName(val),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildLabel(context, 'SPECIALTY *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.specialtyController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Cardiologist',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter specialty';
            }
            if (val.trim().length < 2) {
              return 'Specialty must be at least 2 characters';
            }
            if (!RegExp(r'[a-zA-Z]').hasMatch(val.trim())) {
              return 'Specialty must contain letters';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DoctorHospitalSelectionSection(
          selectedHospitalIds: controller.selectedHospitalIds,
          originalDoctor: originalDoctor,
          onOpenHospitalPicker: onOpenHospitalPicker,
          onRemoveHospital: onRemoveHospital,
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn = constraints.maxWidth >= 340;
            if (isTwoColumn) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPhoneField(context)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _buildEmailField(context)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhoneField(context),
                const SizedBox(height: AppSpacing.md),
                _buildEmailField(context),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _buildLabel(context, 'CLINICAL NOTES / REVIEWS'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add consultation habits, fee notes, clinic hours...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, 'PHONE'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+91 98765 43210',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (val) => Validators.validatePhone(val),
        ),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, 'EMAIL'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'doctor@clinic.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return null;
            return Validators.validateEmail(val);
          },
        ),
      ],
    );
  }
}
