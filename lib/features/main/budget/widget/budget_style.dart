import 'package:flutter/material.dart';

/// Shared cyan–teal styling for the budget feature.
class BudgetStyle {
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

class BudgetActionButton extends StatelessWidget {
  const BudgetActionButton({Key? key, required this.label, this.onPressed,
    this.icon = Icons.check_rounded}) : super(key: key);
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : BudgetStyle.gradient,
        color: onPressed == null ? BudgetStyle.text(context).withOpacity(.10) : null,
      ),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 21, color: onPressed == null
                ? BudgetStyle.muted(context) : BudgetStyle.ink),
            const SizedBox(width: 10),
            Flexible(child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: onPressed == null ? BudgetStyle.muted(context) : BudgetStyle.ink))),
          ]),
        ),
      ),
    ),
  );
}
