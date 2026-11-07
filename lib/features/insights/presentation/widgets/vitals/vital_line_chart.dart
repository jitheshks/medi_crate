import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_typography.dart';
import '../../../../vitals/data/models/measurement_model.dart';
import '../../../data/models/insights_summary_model.dart';
import 'vital_trend_style_helper.dart';

class VitalLineChart extends StatelessWidget {
  final VitalTrendSeries series;
  final ColorScheme colorScheme;

  const VitalLineChart({
    super.key,
    required this.series,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final readings = series.readings;
    final isBP = series.type == MeasurementTypes.bloodPressure;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    if (isBP) {
      for (final r in readings) {
        final sys = r.systolic ?? 120.0;
        final dia = r.diastolic ?? 80.0;
        if (sys > maxY) maxY = sys;
        if (dia < minY) minY = dia;
      }
    } else {
      for (final r in readings) {
        final val =
            r.numericValue ?? VitalTrendStyleHelper.parseNumericValue(r.value);
        if (val > maxY) maxY = val;
        if (val < minY) minY = val;
      }
    }

    if (minY == double.infinity) minY = 50.0;
    if (maxY == double.negativeInfinity) maxY = 150.0;

    final range = (maxY - minY).abs();
    final margin = range > 0 ? range * 0.2 : (minY * 0.15).clamp(5.0, 20.0);
    final chartMinY = (minY - margin).clamp(0.0, double.infinity);
    final chartMaxY = maxY + margin;

    final sysLineColor = colorScheme.primary;
    final diaLineColor = colorScheme.outline;
    final singleLineColor = colorScheme.primary;

    final sysSpots = <FlSpot>[];
    final diaSpots = <FlSpot>[];
    final singleSpots = <FlSpot>[];

    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      final x = i.toDouble();
      if (isBP) {
        sysSpots.add(FlSpot(x, r.systolic ?? 120.0));
        diaSpots.add(FlSpot(x, r.diastolic ?? 80.0));
      } else {
        singleSpots.add(
          FlSpot(
            x,
            r.numericValue ?? VitalTrendStyleHelper.parseNumericValue(r.value),
          ),
        );
      }
    }

    final double maxX = (readings.length - 1).toDouble();
    final double yInterval = range > 0 ? range / 3 : 20.0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: chartMinY,
        maxY: chartMaxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => colorScheme.surface,
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipBorder: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= readings.length) return null;
                final r = readings[idx];
                final dateStr = DateFormat('dd MMM').format(r.recordedAt);
                if (isBP) {
                  return LineTooltipItem(
                    '$dateStr\nSystolic: ${r.systolic?.toInt() ?? 120} mmHg\nDiastolic: ${r.diastolic?.toInt() ?? 80} mmHg',
                    AppTypography.caption.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  );
                }
                return LineTooltipItem(
                  '$dateStr\nvalue : ${r.value}',
                  AppTypography.caption.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: yInterval,
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
              reservedSize: 28,
              interval: yInterval,
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
                  final dt = readings[intVal].recordedAt;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('dd MMM').format(dt),
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
        lineBarsData: isBP
            ? [
                LineChartBarData(
                  spots: sysSpots,
                  isCurved: false,
                  barWidth: 2.5,
                  color: sysLineColor,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: sysLineColor,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                  ),
                  belowBarData: BarAreaData(show: false),
                ),
                LineChartBarData(
                  spots: diaSpots,
                  isCurved: false,
                  barWidth: 2.0,
                  color: diaLineColor,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 3.5,
                          color: diaLineColor,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                  ),
                  belowBarData: BarAreaData(show: false),
                ),
              ]
            : [
                LineChartBarData(
                  spots: singleSpots,
                  isCurved: false,
                  barWidth: 2.5,
                  color: singleLineColor,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                          radius: 4,
                          color: singleLineColor,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                  ),
                ),
              ],
      ),
    );
  }
}
