import 'package:flutter/material.dart';

Color mapColor(dynamic value) {
  if (value is Color) return value;
  if (value is String) {
    switch (value) {
      case 'orange':
      case '#FF9800':
        return Colors.orange;
      case 'blue':
      case '#2196F3':
        return Colors.blue;
      case 'red':
      case '#F44336':
        return Colors.red;
      case 'green':
      case '#4CAF50':
        return Colors.green;
    }
  }
  return Colors.blue;
}

String? mapImage(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

String mapTitle(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return 'other';
}
