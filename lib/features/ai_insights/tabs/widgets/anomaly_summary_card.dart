import 'package:flutter/material.dart';

class AnomalySummaryCard extends StatelessWidget {
  final int total;
  final int detected;
  final dynamic rate;
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
    return _card(
      title: "Tổng quan phát hiện",
      children: [
        _row("Tổng giao dịch", "$total", Colors.blue),
        _row("Giao dịch bất thường", "$detected", Colors.red),
        _row("Tỷ lệ bất thường", "$rate%", Colors.orange),
      ],
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black12)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
