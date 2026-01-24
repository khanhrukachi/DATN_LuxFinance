import 'package:flutter/material.dart';

/// Title của từng section
Widget buildSectionTitle(
    String title, {
      IconData? icon,
      Color? color,
    }) {
  return Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: color ?? Colors.blue),
        const SizedBox(width: 6),
      ],
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );
}

/// Row hiển thị key - value
Widget buildSummaryRow(
    String label,
    String value, {
      Color? valueColor,
    }) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}

/// Hiển thị lỗi trong từng tab
Widget buildTabError(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
