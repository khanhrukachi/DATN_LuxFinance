import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TrendSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool isDarkMode;
  final NumberFormat numberFormat;

  const TrendSummaryCard({
    Key? key,
    required this.summary,
    required this.isDarkMode,
    required this.numberFormat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final predictionPeriod = summary['predictionPeriod'] ?? '7 ngày';
    final totalIncome = summary['totalPredictedIncome'] ?? 0;
    final totalExpense = summary['totalPredictedExpense'] ?? 0;
    final balance = summary['predictedBalance'] ?? 0;

    final isPositive = balance >= 0;

    final bgColor = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
    final shadowColor =
    isDarkMode ? Colors.black26 : const Color(0xFFE0E5EC).withOpacity(0.6);
    final labelColor = isDarkMode ? Colors.white60 : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          /// Header badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  size: 14,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  "Dự báo $predictionPeriod tới",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// Balance
          Column(
            children: [
              Text(
                "Số dư dự kiến",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                numberFormat.format(balance),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: isPositive
                      ? (isDarkMode
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFF059669))
                      : (isDarkMode
                      ? const Color(0xFFF87171)
                      : const Color(0xFFDC2626)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// Income / Expense
          Row(
            children: [
              Expanded(
                child: _buildStatBlock(
                  label: "Thu nhập",
                  value: totalIncome,
                  color: const Color(0xFF10B981),
                  icon: Icons.arrow_upward_rounded,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatBlock(
                  label: "Chi tiêu",
                  value: totalExpense,
                  color: const Color(0xFFEF4444),
                  icon: Icons.arrow_downward_rounded,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock({
    required String label,
    required num value,
    required Color color,
    required IconData icon,
    required bool isDarkMode,
  }) {
    final bgTint = isDarkMode ? color.withOpacity(0.12) : color.withOpacity(0.06);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            numberFormat.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
