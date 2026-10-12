import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared cyan–teal styling for the analytics feature.
class AnalyticStyle {
  static String money(BuildContext context, num value) => NumberFormat.currency(
    locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US',
    symbol: '₫', decimalDigits: 0).format(value);
  static const palette = <Color>[
    Color(0xFF00B8D9), Color(0xFF14988F), Color(0xFF4F7CFF),
    Color(0xFF8C6DE8), Color(0xFFE8A23A), Color(0xFFE87953),
    Color(0xFF3FAF7F), Color(0xFFD36D9F), Color(0xFF718AA0),
  ];
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



class AnalyticTabs extends StatelessWidget {
  const AnalyticTabs({Key? key, required this.controller, required this.tabs,
    this.width, this.margin = EdgeInsets.zero}) : super(key: key);
  final TabController controller;
  final List<Widget> tabs;
  final double? width;
  final EdgeInsetsGeometry margin;
  @override
  Widget build(BuildContext context) => Container(
    margin: margin, width: width, height: 48,
    child: Material(color: AnalyticStyle.background(context),
      borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(4),
        child: TabBar(controller: controller, tabs: tabs,
          dividerColor: Colors.transparent, indicatorSize: TabBarIndicatorSize.tab,
          splashBorderRadius: BorderRadius.circular(12),
          indicator: BoxDecoration(gradient: AnalyticStyle.gradient, borderRadius: BorderRadius.circular(12)),
          labelColor: AnalyticStyle.ink, unselectedLabelColor: AnalyticStyle.muted(context),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        )),
    ),
  );
}

class AnalyticCategoryRow extends StatelessWidget {
  const AnalyticCategoryRow({Key? key, required this.title, required this.amount,
    required this.color, required this.onTap, this.image, this.share}) : super(key: key);
  final String title;
  final num amount;
  final Color color;
  final VoidCallback onTap;
  final String? image;
  final double? share;
  @override
  Widget build(BuildContext context) => Material(color: AnalyticStyle.background(context),
    borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 40, height: 40, padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
            child: image == null ? Icon(Icons.label_outline_rounded, color: color)
              : Image.asset(image!, errorBuilder: (_, __, ___) => Icon(Icons.label_outline_rounded, color: color))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(AnalyticStyle.money(context, amount), style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: amount < 0 ? AnalyticStyle.danger : AnalyticStyle.accent(context))),
            if (share != null && share!.isFinite) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: share!.clamp(0.0, 1.0).toDouble(), minHeight: 5,
                    color: color, backgroundColor: color.withOpacity(.10)))),
                const SizedBox(width: 8),
                Text('${(share! * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: AnalyticStyle.muted(context))),
              ]),
            ],
          ])),
          const SizedBox(width: 8), Icon(Icons.chevron_right_rounded, color: AnalyticStyle.muted(context), size: 20),
        ])),
    ),
  );
}
