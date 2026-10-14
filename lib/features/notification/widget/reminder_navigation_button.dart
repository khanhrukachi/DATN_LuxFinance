import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';

class ReminderNavigationButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const ReminderNavigationButton({super.key, required this.title,
    required this.subtitle, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .55,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: SpendingStyle.gradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SpendingStyle.teal.withOpacity(.25)),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: SpendingStyle.ink),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 15, color: SpendingStyle.ink)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: TextStyle(fontSize: 12, height: 1.4,
                      color: SpendingStyle.ink.withOpacity(.78))),
                ],
              )),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: SpendingStyle.ink),
            ]),
          ),
        ),
      ),
    ),
  );
}

/// Compact AppBar action, matching the debt screen's teal buttons.
class ReminderToolbarButton extends StatelessWidget {
  const ReminderToolbarButton({super.key, required this.tooltip,
    required this.icon, required this.onPressed, this.loading = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = SpendingStyle.accent(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Center(
        child: Material(
          color: SpendingStyle.teal.withOpacity(dark ? .15 : .13),
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42, height: 42,
            child: IconButton(
              tooltip: tooltip,
              padding: EdgeInsets.zero,
              onPressed: loading ? null : onPressed,
              color: accent,
              disabledColor: accent.withOpacity(.4),
              icon: loading
                  ? SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : Icon(icon, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

class ReminderFilterChip extends StatelessWidget {
  const ReminderFilterChip({super.key, required this.label, required this.icon,
    required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = SpendingStyle.accent(context);
    return Semantics(
      button: true, selected: selected,
      child: Material(
        color: selected ? SpendingStyle.teal.withOpacity(.16)
            : SpendingStyle.background(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? accent.withOpacity(.45)
                  : SpendingStyle.teal.withOpacity(.12)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: selected ? accent : SpendingStyle.muted(context)),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : Theme.of(context).colorScheme.onSurface)),
            ]),
          ),
        ),
      ),
    );
  }
}

class ReminderInfoPanel extends StatelessWidget {
  const ReminderInfoPanel({super.key, required this.icon, required this.title,
    this.subtitle, this.hero = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool hero;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: SpendingStyle.decoration(context, hero: hero),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: SpendingStyle.teal.withOpacity(.14),
            borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: SpendingStyle.accent(context)),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(fontSize: 13, height: 1.5,
                color: SpendingStyle.muted(context))),
          ],
        ],
      )),
    ]),
  );
}
