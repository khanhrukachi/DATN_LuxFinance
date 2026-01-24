import 'package:flutter/material.dart';

class TrendAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> trend;
  final bool isDarkMode;

  const TrendAnalysisCard({
    required this.trend,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Phân tích xu hướng",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(trend['recommendation'] ?? "",
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
