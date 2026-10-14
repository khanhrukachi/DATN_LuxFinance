import 'dart:async';

import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_notice_card.dart';

/// Shared styling for the debt feature.
class DebtStyle {
  static OverlayEntry? _activeDebtNotice;
  static Timer? _debtNoticeTimer;

  /// Floating feedback for debt screens.
  static void showNotice(
      BuildContext context,
      String message, {
        bool warningNotice = false,
      }) {
    final isDark = dark(context);
    final color = warningNotice
        ? (isDark ? const Color(0xFFFFC46B) : const Color(0xFF8A4F00))
        : (isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E));
    final backgroundColor = warningNotice
        ? (isDark ? const Color(0xFF352A1C) : const Color(0xFFFFF4E3))
        : (isDark ? const Color(0xFF362322) : const Color(0xFFFFF0EE));
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        elevation: 4,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        duration: Duration(seconds: warningNotice ? 6 : 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(.22)),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                warningNotice
                    ? Icons.warning_amber_rounded
                    : Icons.error_outline_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => messenger.hideCurrentSnackBar(),
              icon: Icon(Icons.close_rounded, color: color, size: 20),
            ),
          ],
        ),
      ),
    );
  }


  static const cyan = Color(0xFF00D2FF);
  static const teal = Color(0xFF2DD8C6);
  static const ink = Color(0xFF073D43);
  static const danger = Color(0xFFE5533D);
  static const warning = Color(0xFFE8A23A);
  static const gradient = LinearGradient(
    colors: [cyan, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color background(BuildContext context) =>
      dark(context) ? const Color(0xFF0E1C22) : const Color(0xFFF3F9FA);
  static Color card(BuildContext context) =>
      dark(context) ? const Color(0xFF172A30) : Colors.white;
  static Color accent(BuildContext context) =>
      dark(context) ? teal : const Color(0xFF14988F);
  static Color text(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color muted(BuildContext context) => text(context).withOpacity(.65);
  static Color status(BuildContext context, double progress) =>
      progress >= 1 ? danger : progress >= .8 ? warning : accent(context);
  static BoxDecoration decoration(BuildContext context, {bool hero = false}) =>
      BoxDecoration(
        color: hero ? null : card(context),
        gradient: !hero ? null : LinearGradient(
          colors: dark(context)
              ? [const Color(0xFF163A46), const Color(0xFF16463F)]
              : [const Color(0xFFE1F7FF), const Color(0xFFDCF9F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(hero ? 26 : 20),
        border: Border.all(color: teal.withOpacity(.16)),
      );
  static InputDecoration input(BuildContext context, String label,
      {IconData? icon, String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: background(context),
    prefixIcon: icon == null ? null : Icon(icon, color: accent(context)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: teal.withOpacity(.16))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent(context), width: 1.5)),
  );
}
