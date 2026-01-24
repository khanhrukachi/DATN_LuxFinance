import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/cluster_item_card.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/cluster_pie_chart.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/cluster_recommendation_item.dart';
import 'package:personal_financial_management/features/ai_insights/tabs/widgets/cluster_summary_card.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class ClusterTab extends StatelessWidget {
  final ClusteringResult result;
  final bool isDarkMode;

  ClusterTab({
    super.key,
    required this.result,
    required this.isDarkMode,
  });

  final numberFormat = NumberFormat.currency(locale: "vi_VI", symbol: "₫");

  @override
  Widget build(BuildContext context) {
    if (!result.success) {
      return Center(
        child: Text(result.errorMessage ?? 'Không có dữ liệu phân cụm'),
      );
    }

    final clusters = result.clusters;
    final profile = result.userProfile;
    final recommendations = result.recommendations;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ===== SUMMARY =====
          ClusterSummaryCard(
            profile: profile,
            numberFormat: numberFormat,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),

          /// ===== PIE CHART =====
          ClusterPieChart(
            clusters: clusters,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 16),

          /// ===== CLUSTERS =====
          const Text(
            'Các nhóm hành vi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...clusters.map(
                (c) => ClusterItemCard(
              cluster: c,
              numberFormat: numberFormat,
              isDarkMode: isDarkMode,
            ),
          ),

          /// ===== RECOMMEND =====
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Khuyến nghị',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...recommendations.map(
                  (r) => ClusterRecommendationItem(
                text: r,
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
