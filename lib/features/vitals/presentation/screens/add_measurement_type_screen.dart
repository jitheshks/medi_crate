import 'package:flutter/material.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../data/models/measurement_model.dart';
import '../widgets/vital_visuals_helper.dart';

/// AddMeasurementTypeScreen presents a 2-column selection grid for the 7 vital types
/// matching reference screenshot `add_measurements.png`.
class AddMeasurementTypeScreen extends StatelessWidget {
  const AddMeasurementTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    const types = [
      {
        'type': MeasurementTypes.bloodPressure,
        'title': 'Blood Pressure',
        'unit': 'mmHg',
      },
      {
        'type': MeasurementTypes.bloodGlucose,
        'title': 'Blood Glucose',
        'unit': 'mg/dL',
      },
      {
        'type': MeasurementTypes.heartRate,
        'title': 'Heart Rate',
        'unit': 'bpm',
      },
      {'type': MeasurementTypes.spo2, 'title': 'SpO₂', 'unit': '%'},
      {
        'type': MeasurementTypes.temperature,
        'title': 'Temperature',
        'unit': '°C',
      },
      {
        'type': MeasurementTypes.bmi,
        'title': 'BMI',
        'unit': 'Calculated from profile',
      },
      {
        'type': MeasurementTypes.respiratoryRate,
        'title': 'Respiratory Rate',
        'unit': 'br/min',
      },
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.measurements),
        ),
        title: Text(
          'Add Measurement',
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What would you like to record?',
                style: AppTypography.subtitle.copyWith(
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // 2-Column Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: types.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final item = types[index];
                  return _buildTypeCard(context, item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(BuildContext context, Map<String, dynamic> item) {
    final typeId = item['type'] as String;
    final title = item['title'] as String;
    final unit = item['unit'] as String;
    final visuals = getVitalVisuals(context, typeId);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        context.pushGuarded(AppRoutes.measurementFormWithType(typeId));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visuals.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(visuals.icon, color: visuals.iconColor, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
