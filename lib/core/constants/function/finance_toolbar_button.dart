import 'package:flutter/material.dart';

/// Shared compact button for finance screens and image controls.
class FinanceToolbarButton extends StatelessWidget {
  const FinanceToolbarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.loading = false,
    this.color,
    this.surfaceColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool loading;
  final Color? color;
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const teal = Color(0xFF2DD8C6);
    final accent = color ?? (dark ? teal : const Color(0xFF14988F));
    final tint = (color ?? teal).withOpacity(dark ? .15 : .13);
    final background = surfaceColor == null
        ? tint
        : Color.alphaBlend(tint, surfaceColor!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 42,
            height: 42,
            child: IconButton(
              tooltip: tooltip,
              padding: EdgeInsets.zero,
              color: accent,
              disabledColor: accent.withOpacity(.4),
              onPressed: loading ? null : onPressed,
              icon: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(icon, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary form action keeps the existing cyan/teal palette and its text label.
class FinanceActionButton extends StatelessWidget {
  const FinanceActionButton({super.key, required this.label,
    required this.onPressed, this.icon = Icons.check_rounded});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .5 : 1,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00D2FF), Color(0xFF2DD8C6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: const Color(0xFF073D43), size: 21),
              const SizedBox(width: 10),
              Flexible(child: Text(label, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF073D43),
                  fontSize: 15, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    ),
  );
}
