import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/anomaly_alert_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/anomaly_empty_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/anomaly_item_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/anomaly_summary_card.dart';
import 'package:personal_financial_management/controls/ml_service.dart';

class AnomalyTab extends StatelessWidget {
  final AnomalyResult result;
  final bool isDarkMode;
  final NumberFormat numberFormat;

  const AnomalyTab({super.key, required this.result, required this.isDarkMode, required this.numberFormat});

  @override
  Widget build(BuildContext context) {
    final anomalies = result.anomalies ?? [];
    final alerts = result.alerts ?? [];
    final stats = result.statistics ?? {};
    final modelReady = stats['modelReady'] == true;
    final rawRate = stats['anomalyRate'];
    final parsedRate = rawRate is num ? rawRate.toDouble() : double.tryParse('$rawRate');
    final rate = parsedRate != null && parsedRate.isFinite ? parsedRate.clamp(0.0, 100.0).toDouble() : 0.0;
    final primary = isDarkMode ? Colors.white : Colors.black87;
    final secondary = isDarkMode ? Colors.white70 : Colors.black54;
    final month = stats['analysisMonth']?.toString();

    return Container(
      color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Khoản chi cần kiểm tra', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary)),
          const SizedBox(height: 6),
          Text(month == null ? 'Đối chiếu với lịch sử chi tiêu của bạn' : 'Phân tích tháng $month',
              style: TextStyle(color: secondary)),
          const SizedBox(height: 8),
          Text('Khác thường không đồng nghĩa với lãng phí. Hãy kiểm tra số tiền, giao dịch trùng và các khoản đã có kế hoạch.',
              style: TextStyle(height: 1.5, color: secondary)),
          const SizedBox(height: 16),
          if (!result.success) ...[
            AnomalyEmptyCard(isDarkMode: isDarkMode, isError: true,
                message: alerts.isNotEmpty ? alerts.join('\n')
                    : 'Có thể chưa đủ dữ liệu hoặc chưa tải được kết quả. Hãy kiểm tra kết nối và tải lại màn hình AI.'),
          ] else ...[
            AnomalySummaryCard(total: result.totalTransactions,
                detected: result.anomaliesDetected, rate: rate, isDarkMode: isDarkMode),
            const SizedBox(height: 12),
            if (!modelReady) Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Chưa xác nhận đủ dữ liệu cho mô hình. Các dấu hiệu hiển thị có thể đến từ quy tắc đối chiếu giao dịch.',
                  style: TextStyle(height: 1.5, color: secondary)),
            ),
            if (alerts.isNotEmpty) ...[
              AnomalyAlertCard(alerts: alerts, isDarkMode: isDarkMode),
              const SizedBox(height: 16),
            ],
            if (anomalies.isEmpty)
              AnomalyEmptyCard(isDarkMode: isDarkMode, analysisReliable: modelReady)
            else ...anomalies.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnomalyItemCard(anomaly: a, isDarkMode: isDarkMode, numberFormat: numberFormat),
            )),
          ],
        ]),
      ),
    );
  }
}
