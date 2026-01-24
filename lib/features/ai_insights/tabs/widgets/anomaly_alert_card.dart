import 'package:flutter/material.dart';

class AnomalyAlertCard extends StatelessWidget {
  final List<String> alerts;
  final bool isDarkMode;

  const AnomalyAlertCard({
    super.key,
    required this.alerts,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notifications_active, color: Colors.orange),
              SizedBox(width: 8),
              Text("Cảnh báo",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(e,
                style: TextStyle(
                    color:
                    isDarkMode ? Colors.white : Colors.black87)),
          )),
        ],
      ),
    );
  }
}
