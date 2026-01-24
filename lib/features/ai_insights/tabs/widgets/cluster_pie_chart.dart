import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class ClusterPieChart extends StatelessWidget {
  final List<SpendingCluster> clusters;
  final bool isDarkMode;

  const ClusterPieChart({
    super.key,
    required this.clusters,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 40,
          sections: clusters.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return PieChartSectionData(
              value: c.percentage,
              title: '${c.percentage.toStringAsFixed(1)}%',
              color: colors[i % colors.length],
              titleStyle: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
