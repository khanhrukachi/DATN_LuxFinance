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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: severity.color, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(severity),
            const SizedBox(height: 8),
            _buildDate(),
            const SizedBox(height: 10),
            _buildReason(),
          ],
        ),
      ),
    );
  }

  /// Header: badge + loại + tiền
  Widget _buildHeader(_Severity severity) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _badge(severity),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            anomaly.typeName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
        Text(
          numberFormat.format(anomaly.money),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: anomaly.money < 0 ? Colors.redAccent : Colors.green,
          ),
        ),
      ],
    );
  }

  /// Ngày giờ
  Widget _buildDate() {
    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 14,
          color: isDarkMode ? Colors.white54 : Colors.black45,
        ),
        const SizedBox(width: 4),
        Text(
          anomaly.dateTime,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white60 : Colors.black45,
          ),
        ),
      ],
    );
  }

  /// Lý do bất thường
  Widget _buildReason() {
    return Text(
      anomaly.anomalyReason,
      textAlign: TextAlign.justify,
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: isDarkMode ? Colors.white70 : Colors.black54,
      ),
    );
  }

  _Severity _severity() {
    switch (anomaly.severity) {
      case 'high':
        return _Severity("Cao", Colors.redAccent);
      case 'medium':
        return _Severity("TB", Colors.orangeAccent);
      default:
        return _Severity("Thấp", Colors.green);
    }
  }

  Widget _badge(_Severity s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        s.text,
        style: TextStyle(
          color: s.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Severity {
  final String text;
  final Color color;
  _Severity(this.text, this.color);
}
