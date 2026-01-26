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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(width: 14),
            Expanded(child: _buildText()),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.tips_and_updates_rounded,
        color: Colors.amber,
        size: 20,
      ),
    );
  }

  Widget _buildText() {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
