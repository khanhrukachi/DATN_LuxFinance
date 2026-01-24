import 'package:flutter/material.dart';

class ClusterRecommendationItem extends StatelessWidget {
  final String text;
  final bool isDarkMode;

  const ClusterRecommendationItem({
    super.key,
    required this.text,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text))
        ],
      ),
    );
  }
}
