import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class ClusterPieChart extends StatelessWidget {
  final List<SpendingCluster> clusters;
  final bool isDarkMode;

  const ClusterPieChart({
    Key? key,
    required this.clusters,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle(),
            const SizedBox(height: 12),
            clusters.isEmpty ? _buildEmptyState() : _buildChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        Icon(
          Icons.pie_chart,
          size: 20,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        const SizedBox(width: 8),
        Text(
          'Phân bố cụm chi tiêu',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 42,
          sectionsSpace: 2,
          sections: clusters.asMap().entries.map((entry) {
            final index = entry.key;
            final cluster = entry.value;

            return PieChartSectionData(
              value: cluster.percentage,
              title: '${cluster.percentage.toStringAsFixed(1)}%',
              color: colors[index % colors.length],
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: isDarkMode ? Colors.white54 : Colors.black45,
            ),
            const SizedBox(height: 8),
            Text(
              'Không có dữ liệu phân cụm',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
