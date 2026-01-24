import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/anomaly_alert_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/anomaly_empty_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/anomaly_item_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/anomaly_summary_card.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class AnomalyTab extends StatelessWidget {
  final AnomalyResult result;
  final bool isDarkMode;
  final NumberFormat numberFormat;

  const AnomalyTab({
    super.key,
    required this.result,
    required this.isDarkMode,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    final anomalies = result.anomalies ?? [];
    final alerts = result.alerts ?? [];
    final stats = result.statistics ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnomalySummaryCard(
            total: result.totalTransactions,
            detected: result.anomaliesDetected,
            rate: (stats['anomalyRate'] as num?)?.toDouble() ?? 0.0,
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 16),

          if (alerts.isNotEmpty)
            AnomalyAlertCard(
              alerts: alerts,
              isDarkMode: isDarkMode,
            ),

          const SizedBox(height: 16),

          if (anomalies.isNotEmpty)
            ...anomalies.map(
                  (a) => AnomalyItemCard(
                anomaly: a,
                isDarkMode: isDarkMode,
                numberFormat: numberFormat,
              ),
            )
          else
            AnomalyEmptyCard(isDarkMode: isDarkMode),
        ],
      ),
    );
  }
}
