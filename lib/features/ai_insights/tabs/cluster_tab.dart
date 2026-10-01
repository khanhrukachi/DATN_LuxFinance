import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/cluster_item_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/cluster_pie_chart.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/cluster_recommendation_item.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/cluster_summary_card.dart';
import 'package:personal_financial_management/controls/ml_service.dart';

class ClusterTab extends StatelessWidget {
  final ClusteringResult result;
  final bool isDarkMode;

  ClusterTab({
    super.key,
    required this.result,
    required this.isDarkMode,
  });

  final numberFormat = NumberFormat.currency(locale: "vi_VI", symbol: "₫", decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    if (!result.success) {
      return Container(
        color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
        child: Center(
          child: Text(
            result.errorMessage ?? 'Không có dữ liệu phân cụm',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      );
    }

    final clusters = result.clusters;
    final profile = result.userProfile;
    final recommendations = result.recommendations;
    final rawInfo = profile['kMeans'];
    final info = rawInfo is Map ? rawInfo : <String, dynamic>{};
    final scope = info['scope']?.toString();

    return Container(
      // ✅ NỀN RIÊNG – KHÔNG DÍNH TAB KHÁC
      color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thói quen chi tiêu', style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 6),
            Text(scope != null && scope != 'provided_history'
                ? 'Dữ liệu tháng $scope'
                : 'Phân tích trên lịch sử giao dịch được gửi lên',
                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            Text('Các nhóm thể hiện giao dịch có đặc điểm tương đồng, không tự xác định khoản chi lãng phí.',
                style: TextStyle(height: 1.4, color: isDarkMode ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            if (recommendations.isNotEmpty) ...[
              Text('Điều bạn có thể cân nhắc', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              ...recommendations.map((r) => ClusterRecommendationItem(text: r, isDarkMode: isDarkMode)),
              const SizedBox(height: 16),
            ],
            ClusterSummaryCard(
              profile: profile,
              numberFormat: numberFormat,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),

            ClusterPieChart(
              clusters: clusters,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),

            Text(
              'Các nhóm giao dịch tương đồng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            ...clusters.map(
                  (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClusterItemCard(
                  cluster: c,
                  numberFormat: numberFormat,
                  isDarkMode: isDarkMode,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
