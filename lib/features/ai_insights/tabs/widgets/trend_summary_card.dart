import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TrendSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool isDarkMode;
  final NumberFormat numberFormat;

  const TrendSummaryCard({
    required this.summary,
    required this.isDarkMode,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dự báo ${summary['predictionPeriod']} ngày",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _row("Thu nhập", summary['totalPredictedIncome'], Colors.green),
            _row("Chi tiêu", summary['totalPredictedExpense'], Colors.red),
            _row("Cân đối", summary['predictedBalance'],
                summary['predictedBalance'] >= 0 ? Colors.green : Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, num value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          numberFormat.format(value),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
