import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../vitals/data/models/measurement_model.dart';
import '../../../data/models/insights_summary_model.dart';
import 'vital_trend_style_helper.dart';

class VitalBarChart extends StatelessWidget {
  final VitalTrendSeries series;
  final ColorScheme colorScheme;

  const VitalBarChart({
    super.key,
    required this.series,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final readings = series.readings;
    final isBP = series.type == MeasurementTypes.bloodPressure;

    double maxY = 0.0;
    if (isBP) {
      for (final r in readings) {
        final sys = r.systolic ?? 120.0;
        if (sys > maxY) maxY = sys;
      }
    } else {
      for (final r in readings) {
        final val =
            r.numericValue ?? VitalTrendStyleHelper.parseNumericValue(r.value);
        if (val > maxY) maxY = val;
      }
    }

    final chartMaxY = maxY > 0 ? maxY * 1.25 : 100.0;
    final sysColor = colorScheme.primary;
    final diaColor = colorScheme.outline;

    return BarChart(
      BarChartData(
        maxY: chartMaxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final idx = group.x;
              if (idx < 0 || idx >= readings.length) return null;
              final r = readings[idx];
              return BarTooltipItem(
                '${r.value} ${r.unit}',
                AppTypography.caption.copyWith(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, meta) {
                return Text(
                  val.toInt().toString(),
                  style: AppTypography.caption.copyWith(
                    fontSize: 9,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1.0,
              getTitlesWidget: (val, meta) {
                final intVal = val.round();
                if ((val - intVal).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                if (intVal >= 0 && intVal < readings.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('dd MMM').format(readings[intVal].recordedAt),
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: readings.asMap().entries.map((entry) {
          final idx = entry.key;
          final r = entry.value;

          if (isBP) {
            final sys = r.systolic ?? 120.0;
            final dia = r.diastolic ?? 80.0;
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: sys,
                  color: sysColor,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: dia,
                  color: diaColor,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          } else {
            final val =
                r.numericValue ??
                VitalTrendStyleHelper.parseNumericValue(r.value);
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: sysColor,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ],
            );
          }
        }).toList(),
      ),
    );
  }
}
