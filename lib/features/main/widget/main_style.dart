import 'package:flutter/material.dart';

class MainStyle {
  static const cyan = Color(0xFF00D2FF);
  static const teal = Color(0xFF2DD8C6);
  static const ink = Color(0xFF073D43);
  static const danger = Color(0xFFE5533D);
  static const gradient = LinearGradient(colors: [cyan, teal], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static bool dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color card(BuildContext context) => dark(context) ? const Color(0xFF172A30) : Colors.white;
  static Color background(BuildContext context) => dark(context) ? const Color(0xFF0E1C22) : const Color(0xFFF3F9FA);
  static Color accent(BuildContext context) => dark(context) ? teal : const Color(0xFF14988F);
  static Color text(BuildContext context) => dark(context) ? const Color(0xFFE6EEF0) : const Color(0xFF193A43);
  static Color muted(BuildContext context) => text(context).withOpacity(.6);
  static OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color));
  static InputDecoration input(BuildContext context, String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, size: 20, color: accent(context)),
    filled: true, fillColor: background(context),
    labelStyle: TextStyle(fontSize: 13, color: muted(context)), errorMaxLines: 3,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(teal.withOpacity(.2)), enabledBorder: border(teal.withOpacity(.2)),
    focusedBorder: border(accent(context)));
}
