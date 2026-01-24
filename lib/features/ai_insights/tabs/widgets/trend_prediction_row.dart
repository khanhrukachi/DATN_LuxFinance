import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class TrendPredictionRow extends StatelessWidget {
  final PredictedValue prediction;
  final bool isDarkMode;
  final NumberFormat numberFormat;

  const TrendPredictionRow({
    required this.prediction,
    required this.isDarkMode,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(prediction.date),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text("+${numberFormat.format(prediction.predictedIncome)}",
              style: const TextStyle(color: Colors.green)),
          Text("-${numberFormat.format(prediction.predictedExpense)}",
              style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
