import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/ml_service.dart';

class AnomalyItemCard extends StatelessWidget {
  final AnomalyTransaction anomaly;
  final bool isDarkMode;
  final NumberFormat numberFormat;

  const AnomalyItemCard({
    super.key,
    required this.anomaly,
    required this.isDarkMode,
    required this.numberFormat,
  });

  @override
  Widget build(BuildContext context) {
    final severity = _severity();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: severity.color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(severity),
              const SizedBox(width: 8),
              Expanded(
                child: Text(anomaly.typeName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black)),
              ),
              Text(
                numberFormat.format(anomaly.money),
                style: TextStyle(
                    color: anomaly.money < 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(anomaly.dateTime,
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white60 : Colors.black45)),
          const SizedBox(height: 8),
          Text(anomaly.anomalyReason,
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54)),
        ],
      ),
    );
  }

  _Severity _severity() {
    switch (anomaly.severity) {
      case 'high':
        return _Severity("Cao", Colors.red);
      case 'medium':
        return _Severity("TB", Colors.orange);
      default:
        return _Severity("Thấp", Colors.green);
    }
  }

  Widget _badge(_Severity s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(s.text,
          style: TextStyle(color: s.color, fontSize: 12)),
    );
  }
}

class _Severity {
  final String text;
  final Color color;
  _Severity(this.text, this.color);
}
