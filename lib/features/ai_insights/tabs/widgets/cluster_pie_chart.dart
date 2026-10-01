import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:personal_financial_management/controls/ml_service.dart';

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
            Text('Phần trăm tính theo số giao dịch, không phải số tiền.',
                style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            clusters.isEmpty ? _buildEmptyState() : _buildChart(),
            if (clusters.isNotEmpty) Wrap(spacing: 12, runSpacing: 10, children: [
              for (final cluster in clusters) Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 10,
                    color: Colors.primaries[cluster.clusterId.abs() % Colors.primaries.length]),
                const SizedBox(width: 5),
                Flexible(child: Text(cluster.clusterName,
                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87))),
              ]),
            ]),
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
        Expanded(child: Text(
          'Tỷ lệ số giao dịch theo nhóm',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        )),
      ],
    );
  }

  Widget _buildChart() {
    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 42,
          sectionsSpace: 2,
          sections: clusters.asMap().entries.map((entry) {
            final cluster = entry.value;

            return PieChartSectionData(
              value: cluster.percentage,
              title: '${cluster.percentage.toStringAsFixed(1)}%',
              color: Colors.primaries[cluster.clusterId.abs() % Colors.primaries.length],
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
