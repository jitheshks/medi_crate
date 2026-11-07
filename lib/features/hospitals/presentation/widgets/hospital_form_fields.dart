import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import 'form/hospital_form_controller.dart';

class HospitalFormFields extends StatelessWidget {
  final HospitalFormController controller;

  static const List<String> facilityTypes = [
    'Hospital',
    'Clinic',
    'Lab',
    'Diagnostic Center',
  ];

  const HospitalFormFields({super.key, required this.controller});

  Widget _buildFieldLabel(BuildContext context, String label) {
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
        _buildFieldLabel(context, 'FACILITY NAME *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.nameController,
          decoration: InputDecoration(
            hintText: 'e.g. Apollo Hospital / City Heart Clinic',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter facility name';
            }
            if (value.trim().length < 2) {
              return 'Facility name must be at least 2 characters';
            }
            if (!RegExp(r'[a-zA-Z]').hasMatch(value.trim())) {
              return 'Facility name must contain letters';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _buildFieldLabel(context, 'FACILITY TYPE'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: facilityTypes.contains(controller.typeController.text)
              ? controller.typeController.text
              : 'Hospital',
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: facilityTypes.map((t) {
            return DropdownMenuItem(value: t, child: Text(t));
          }).toList(),
          onChanged: (val) {
            if (val != null) controller.typeController.text = val;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _buildFieldLabel(context, 'ADDRESS / LOCATION'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.addressController,
          decoration: InputDecoration(
            hintText: 'e.g. Kochi, Kerala',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            if (!RegExp(r'[a-zA-Z0-9]').hasMatch(value.trim())) {
              return 'Please enter a valid address';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(context, 'PHONE'),
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
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(context, 'EMAIL'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: controller.emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'contact@apollo.com',
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
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildFieldLabel(context, 'NOTES'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Working hours, floor details, department notes...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
