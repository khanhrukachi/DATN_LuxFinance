import 'package:flutter/material.dart';

class TrendAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> trend;
  final bool isDarkMode;

  const TrendAnalysisCard({
    Key? key,
    required this.trend,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF1F2937);
    final shadowColor = isDarkMode ? Colors.black45 : const Color(0xFF94A3B8).withOpacity(0.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -4,
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
                  color: Colors.indigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  size: 20,
                  color: isDarkMode ? Colors.indigoAccent : Colors.indigo[700],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Phân tích xu hướng",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildTrendBox(
            label: "Thu nhập",
            value: trend['incomeTrend'] ?? "Chưa có dữ liệu",
          ),

          _buildTrendBox(
            label: "Chi tiêu",
            value: trend['expenseTrend'] ?? "Chưa có dữ liệu",
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xFF1E3A8A).withOpacity(0.3), const Color(0xFF1E40AF).withOpacity(0.1)]
                    : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode ? Colors.blueAccent.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Gợi ý từ AI",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.blue[200] : Colors.blue[900],
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trend['recommendation'] ?? "Hãy tiếp tục theo dõi chi tiêu.",
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDarkMode ? Colors.white70 : Colors.blueGrey[800],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBox({required String label, required String value}) {
    IconData icon;
    Color themeColor;

    final valLower = value.toLowerCase();
    if (valLower.contains("tăng")) {
      icon = Icons.trending_up_rounded;
      themeColor = label == "Thu nhập" ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    } else if (valLower.contains("giảm")) {
      icon = Icons.trending_down_rounded;
      themeColor = label == "Thu nhập" ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    } else {
      icon = Icons.horizontal_rule_rounded;
      themeColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: themeColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white38 : Colors.grey[500],
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}