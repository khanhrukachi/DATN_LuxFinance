import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/trend_analysis_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/trend_chart.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/trend_prediction_row.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/trend_summary_card.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class TrendTab extends StatelessWidget {
  final TrendPredictionResult result;
  final bool isDarkMode;

  TrendTab({
    required this.result,
    required this.isDarkMode,
  });

  final numberFormat = NumberFormat.currency(locale: "vi_VI", symbol: "₫");

  @override
  Widget build(BuildContext context) {
    if (!result.success) {
      return Center(child: Text(result.errorMessage ?? "Không có dữ liệu"));
    }

    final predictions = result.predictions;
    final summary = result.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrendSummaryCard(
            summary: summary,
            isDarkMode: isDarkMode,
            numberFormat: numberFormat,
          ),
          const SizedBox(height: 16),

          TrendChart(
            predictions: predictions,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),

          if (summary['trend'] != null)
            TrendAnalysisCard(
              trend: summary['trend'],
              isDarkMode: isDarkMode,
            ),

          const SizedBox(height: 16),

          ...predictions.map(
                (p) => TrendPredictionRow(
              prediction: p,
              isDarkMode: isDarkMode,
              numberFormat: numberFormat,
            ),
          ),
        ],
      ),
    );
  }
}

