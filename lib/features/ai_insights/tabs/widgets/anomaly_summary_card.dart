import 'package:flutter/material.dart';

class AnomalySummaryCard extends StatelessWidget {
  final int total;
  final int detected;
  final double rate;
  final bool isDarkMode;

  const AnomalySummaryCard({
    super.key,
    required this.total,
    required this.detected,
    required this.rate,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
    isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary =
    isDarkMode ? Colors.white : Colors.black87;
    final textSecondary =
    isDarkMode ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 4),
            color: isDarkMode
                ? Colors.black.withOpacity(0.4)
                : Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== HEADER =====
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Tổng quan phát hiện",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _statRow(
            label: "Tổng giao dịch",
            value: "$total",
            color: Colors.blue,
            textSecondary: textSecondary,
          ),
          _statRow(
            label: "Giao dịch bất thường",
            value: "$detected",
            color: Colors.red,
            textSecondary: textSecondary,
          ),
          _statRow(
            label: "Tỷ lệ bất thường",
            value: "${rate.toStringAsFixed(2)}%",
            color: Colors.orange,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _statRow({
    required String label,
    required String value,
    required Color color,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
