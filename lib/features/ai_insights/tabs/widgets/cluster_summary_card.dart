import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClusterSummaryCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final NumberFormat numberFormat;
  final bool isDarkMode;

  const ClusterSummaryCard({
    super.key,
    required this.profile,
    required this.numberFormat,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hồ sơ chi tiêu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _row('Tổng chi tiêu', profile['totalSpent'], Colors.red),
            _row('Giao dịch TB', profile['averageTransaction'], Colors.blue),
            _row(
              'Số giao dịch',
              profile['transactionCount'],
              Colors.purple,
              isMoney: false,
            ),
            if (profile['spendingStyle'] != null) ...[
              const SizedBox(height: 8),
              Text(
                profile['spendingStyle'],
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _row(
      String label,
      dynamic value,
      Color color, {
        bool isMoney = true,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          isMoney ? numberFormat.format(value ?? 0) : value.toString(),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
