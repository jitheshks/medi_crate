import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../vitals/data/models/measurement_types.dart';
import 'doctor_summary_section_card.dart';

/// DoctorSummaryVitalsTrendCard groups vital signs by measurement type and renders
/// chronological trend charts when multiple readings exist, or single-reading cards
/// with an insufficient-data notice when only one reading exists.
class DoctorSummaryVitalsTrendCard extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> groupedVitals;

  const DoctorSummaryVitalsTrendCard({super.key, required this.groupedVitals});

  @override
  Widget build(BuildContext context) {
    if (groupedVitals.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return DoctorSummarySectionCard(
      title: 'Vital Signs & Trends',
      icon: Icons.favorite_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groupedVitals.entries.map((entry) {
          final typeKey = entry.key;
          final readings = entry.value;
          final displayName = MeasurementTypes.getDisplayName(typeKey);
          final unit =
              readings.first['unit']?.toString() ??
              MeasurementTypes.getDefaultUnit(typeKey);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Header & Latest Value
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayName,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (readings.isNotEmpty) ...[
                        _buildStatusBadge(
                          context,
                          readings.last['status']?.toString() ?? 'NORMAL',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (readings.length >= 2) ...[
                    // Multiple readings: show latest summary + trend chart
                    Text(
                      'Latest: ${readings.last['value']} $unit · ${readings.length} readings recorded',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: _buildTrendChart(context, typeKey, readings),
                    ),
                    const SizedBox(height: 8),
                    // Date range axis label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatReadingDate(readings.first),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatReadingDate(readings.last),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    // Individual Readings List with individual recorded dates
                    Text(
                      'Measurement History (${readings.length})',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...readings.reversed.map((reading) {
                      final val = reading['value']?.toString() ?? '';
                      final status = reading['status']?.toString() ?? 'NORMAL';
                      final dtStr = _formatReadingDateTime(reading);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$val $unit',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusBadge(context, status),
                              ],
                            ),
                            Text(
                              dtStr,
                              style: AppTypography.caption.copyWith(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    // Single reading: show value and insufficient-data notice
                    Row(
                      children: [
                        Text(
                          '${readings.first['value']} $unit',
                          style: AppTypography.h3.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· Recorded on ${_formatReadingDateTime(readings.first)}',
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Single reading · Insufficient data for trend line',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final upper = status.toUpperCase();
    Color bgColor = Theme.of(context).colorScheme.primaryContainer;
    Color textColor = Theme.of(context).colorScheme.primary;

    if (upper.contains('HIGH') ||
        upper.contains('CRITICAL') ||
        upper.contains('ABOVE')) {
      bgColor = context.semanticColors.statusCritical.withValues(alpha: 0.15);
      textColor = context.semanticColors.statusCritical;
    } else if (upper.contains('ELEVATED') ||
        upper.contains('WARNING') ||
        upper.contains('LOW')) {
      bgColor = context.semanticColors.statusWarning.withValues(alpha: 0.15);
      textColor = context.semanticColors.statusWarning;
    } else if (upper.contains('NORMAL') || upper.contains('WITHIN')) {
      bgColor = context.semanticColors.success.withValues(alpha: 0.15);
      textColor = context.semanticColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        upper,
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    String type,
    List<Map<String, dynamic>> readings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBp =
        type.toLowerCase().contains('blood_pressure') ||
        type.toLowerCase().contains('bp');

    if (isBp) {
      // Blood Pressure: Systolic & Diastolic lines
      final List<FlSpot> sysSpots = [];
      final List<FlSpot> diaSpots = [];

      for (int i = 0; i < readings.length; i++) {
        final r = readings[i];
        double? sys = double.tryParse(r['systolic']?.toString() ?? '');
        double? dia = double.tryParse(r['diastolic']?.toString() ?? '');

        if (sys == null || dia == null) {
          final val = r['value']?.toString() ?? '';
          if (val.contains('/')) {
            final parts = val.split('/');
            sys = double.tryParse(parts[0].trim());
            dia = double.tryParse(parts[1].trim());
          }
        }

        if (sys != null && dia != null) {
          sysSpots.add(FlSpot(i.toDouble(), sys));
          diaSpots.add(FlSpot(i.toDouble(), dia));
        }
      }

      if (sysSpots.isEmpty) {
        return const Center(child: Text('Insufficient numeric values'));
      }

      return LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: sysSpots,
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
            ),
            LineChartBarData(
              spots: diaSpots,
              isCurved: true,
              color: context.semanticColors.statusWarning,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      );
    }

    // Standard single-numeric vital line chart
    final List<FlSpot> spots = [];
    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      final valStr =
          r['numeric_value']?.toString() ?? r['value']?.toString() ?? '';
      final numVal = double.tryParse(valStr.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (numVal != null) {
        spots.add(FlSpot(i.toDouble(), numVal));
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('Insufficient numeric values'));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  String _formatReadingDate(Map<String, dynamic> r) {
    final raw = r['recorded_at'] ?? r['date'] ?? r['created_at'];
    return DateFormatter.formatIndianDate(raw, fallback: 'N/A');
  }

  String _formatReadingDateTime(Map<String, dynamic> r) {
    final raw = r['recorded_at'] ?? r['date'] ?? r['created_at'];
    return DateFormatter.formatIndianDateTime(raw, fallback: 'N/A');
  }
}
