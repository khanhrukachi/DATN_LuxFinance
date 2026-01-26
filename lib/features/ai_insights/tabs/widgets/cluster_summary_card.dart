import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClusterSummaryCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final NumberFormat numberFormat;
  final bool isDarkMode;

  const ClusterSummaryCard({
    super.key,
    required this.profile,
    required this.numberFormat,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final shadowColor = isDarkMode ? Colors.black54 : const Color(0xFF94A3B8).withOpacity(0.2);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                        ).createShader(bounds),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Hồ sơ tài chính',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildModernRow(
                    'Tổng chi tiêu',
                    profile['totalSpent'],
                    const Color(0xFFEF4444),
                    Icons.account_balance_rounded,
                  ),
                  _buildModernRow(
                    'Trung bình/GD',
                    profile['averageTransaction'],
                    const Color(0xFF3B82F6),
                    Icons.confirmation_number_outlined,
                  ),
                  _buildModernRow(
                    'Số giao dịch',
                    profile['transactionCount'],
                    const Color(0xFF10B981),
                    Icons.sync_alt_rounded,
                    isMoney: false,
                    unit: ' lần',
                    isLast: true,
                  ),
                ],
              ),
            ),
            if (profile['spendingStyle'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [Colors.purple.withOpacity(0.15), Colors.blue.withOpacity(0.15)]
                        : [const Color(0xFFF5F3FF), const Color(0xFFEFF6FF)],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_outlined, size: 20, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile['spendingStyle'],
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white70 : const Color(0xFF4B5563),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
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

  Widget _buildModernRow(
      String label,
      dynamic value,
      Color color,
      IconData icon,
      {bool isMoney = true, String unit = '', bool isLast = false}
      ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDarkMode ? Colors.white24 : Colors.black26),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            isMoney ? numberFormat.format(value ?? 0) : "${value ?? 0}$unit",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}