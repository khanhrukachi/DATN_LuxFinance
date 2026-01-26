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
    Key? key,
    required this.result,
    required this.isDarkMode,
  }) : super(key: key);

  final numberFormat = NumberFormat.currency(locale: "vi_VI", symbol: "₫");

  @override
  Widget build(BuildContext context) {
    if (!result.success) {
      return Container(
        color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
        child: Center(
          child: Text(
            result.errorMessage ?? "Không có dữ liệu",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      );
    }

    final predictions = result.predictions;
    final summary = result.summary;

    return Container(
      color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrendSummaryCard(
              summary: summary,
              isDarkMode: isDarkMode,
              numberFormat: numberFormat,
            ),

            const SizedBox(height: 12),

            TrendChart(
              predictions: predictions,
              isDarkMode: isDarkMode,
            ),

            if (summary['trend'] != null) ...[
              const SizedBox(height: 12),
              TrendAnalysisCard(
                trend: summary['trend'],
                isDarkMode: isDarkMode,
              ),
            ],

            const SizedBox(height: 20),

            // 🔶 Card chi tiết dự báo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black26
                        : Colors.black12,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.insights,
                          size: 20,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Chi tiết dự báo",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF2D3142),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  ...predictions.map(
                        (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TrendPredictionRow(
                        prediction: p,
                        isDarkMode: isDarkMode,
                        numberFormat: numberFormat,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
