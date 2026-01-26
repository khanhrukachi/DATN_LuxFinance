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

      // ❌ KHÔNG color
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),

        // ✅ CHỈ GRADIENT CAM
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDarkMode
              ? [
            Colors.orange.withOpacity(0.25),
            Colors.orange.withOpacity(0.15),
          ]
              : [
            Colors.orange.withOpacity(0.18),
            Colors.orange.withOpacity(0.08),
          ],
        ),

        border: Border.all(
          color: Colors.orange.withOpacity(0.45),
          width: 1,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== HEADER =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.notifications_active,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Cảnh báo bất thường",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ===== ALERT LIST =====
          ...alerts.map(
                (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.9)
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
