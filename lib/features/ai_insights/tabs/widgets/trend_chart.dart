import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class TrendChart extends StatelessWidget {
  final List<PredictedValue> predictions;
  final bool isDarkMode;

  const TrendChart({
    required this.predictions,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    if (predictions.isEmpty) return const SizedBox();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: predictions.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: p.predictedIncome, color: Colors.green),
                BarChartRodData(toY: p.predictedExpense, color: Colors.red),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  predictions[v.toInt()].date.substring(5),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }
}
