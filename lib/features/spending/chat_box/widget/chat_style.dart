import 'package:flutter/material.dart';

/// Shared appearance for the financial secretary widgets.
class ChatStyle {
  const ChatStyle(this.context);
  final BuildContext context;
  bool get dark => Theme.of(context).brightness == Brightness.dark;
  Color get pageColor => dark ? const Color(0xFF0E1C22) : const Color(0xFFF3F9FA);
  Color get cardColor => dark ? const Color(0xFF172A30) : Colors.white;
  Color get textColor => dark ? Colors.white : const Color(0xFF16343C);
  Color get mutedColor => dark ? Colors.white60 : const Color(0xFF687386);
}
