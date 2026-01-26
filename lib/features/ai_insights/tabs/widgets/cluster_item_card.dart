import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class ClusterItemCard extends StatelessWidget {
  final SpendingCluster cluster;
  final NumberFormat numberFormat;
  final bool isDarkMode;

  const ClusterItemCard({
    super.key,
    required this.cluster,
    required this.numberFormat,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[cluster.clusterId % Colors.primaries.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${cluster.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cluster.clusterName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              cluster.description,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
            // ------------------------------

            if (cluster.characteristics['averageAmount'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'TB: ${numberFormat.format(cluster.characteristics['averageAmount'])}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}