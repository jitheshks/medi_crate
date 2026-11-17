import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/app_currency.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../data/models/insights_summary_model.dart';

class MonthlyExpenseChart extends StatelessWidget {
  final InsightsSummaryModel summary;
  final bool isLineView;
  final String currency;

  const MonthlyExpenseChart({
    super.key,
    required this.summary,
    required this.isLineView,
    this.currency = 'INR',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLineView) {
      return _buildMonthlyLineChart(context, colorScheme);
    }
    return _buildMonthlyBarChart(context, colorScheme);
  }

  Widget _buildMonthlyBarChart(BuildContext context, ColorScheme colorScheme) {
    final symbol = AppCurrency.getSymbol(currency);
    final items = summary.monthlyExpenses;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No data for selected period',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxVal = items.fold<double>(
      0.0,
      (max, item) => item.amount > max ? item.amount : max,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal > 0 ? maxVal * 1.2 : 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  '$symbol ${rod.toY.toStringAsFixed(0)}',
                  AppTypography.caption.copyWith(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
        titlesData: FlTitlesData(
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
              getTitlesWidget: (value, meta) => value == 0
                  ? Text(
                      '0',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1.0,
              getTitlesWidget: (value, meta) {
                final intVal = value.round();
                if ((value - intVal).abs() > 0.01 ||
                    intVal < 0 ||
                    intVal >= items.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    items[intVal].monthLabel,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal > 0 ? maxVal / 3 : 25,
          getDrawingHorizontalLine: (val) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: item.amount,
                color: colorScheme.primary,
                width: 38,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlyLineChart(BuildContext context, ColorScheme colorScheme) {
    final symbol = AppCurrency.getSymbol(currency);
    final items = summary.monthlyExpenses;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No data for selected period',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxVal = items.fold<double>(
      0.0,
      (max, item) => item.amount > max ? item.amount : max,
    );

    final spots = items.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.amount);
    }).toList();

    final isSinglePoint = items.length == 1;
    final double minX = isSinglePoint ? -0.5 : 0.0;
    final double maxX = isSinglePoint ? 0.5 : (items.length - 1).toDouble();
    final double yInterval = maxVal > 0 ? maxVal / 3 : 25.0;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxVal > 0 ? maxVal * 1.15 : 100,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final amt = spot.y
                  .toStringAsFixed(0)
                  .replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]},',
                  );
              return LineTooltipItem(
                '$symbol $amt',
                AppTypography.caption.copyWith(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
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
              getTitlesWidget: (value, meta) {
                final formatted = value >= 1000
                    ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
                    : value.toStringAsFixed(0);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    formatted,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1.0,
              getTitlesWidget: (value, meta) {
                final intVal = value.round();
                if ((value - intVal).abs() > 0.01 ||
                    intVal < 0 ||
                    intVal >= items.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    items[intVal].monthLabel,
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
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
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: colorScheme.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: colorScheme.primary,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
