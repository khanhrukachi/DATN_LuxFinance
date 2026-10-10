import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

/// Shared cyan–teal styling for the home feature.
class HomeStyle {
  static String money(BuildContext context, num value) => NumberFormat.currency(
    locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US',
    symbol: '₫', decimalDigits: 0).format(value);
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


class HomeCategoryTile extends StatelessWidget {
  const HomeCategoryTile({Key? key, required this.title, required this.money,
    required this.onTap, this.image, this.isParent = false, this.isExpanded = false}) : super(key: key);
  final String title;
  final int money;
  final String? image;
  final bool isParent, isExpanded;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Material(color: HomeStyle.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: HomeStyle.teal.withOpacity(isParent ? .20 : .10))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap,
        child: Padding(padding: EdgeInsets.all(isParent ? 16 : 12),
          child: Row(children: [
            Container(width: isParent ? 48 : 40, height: isParent ? 48 : 40,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: HomeStyle.teal.withOpacity(.10),
                borderRadius: BorderRadius.circular(14)),
              child: image == null
                ? Icon(isParent ? Icons.folder_outlined : Icons.label_outline_rounded, color: HomeStyle.accent(context))
                : Image.asset(image!, errorBuilder: (_, __, ___) => Icon(
                    isParent ? Icons.folder_outlined : Icons.label_outline_rounded, color: HomeStyle.accent(context))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: isParent ? 15 : 14,
                fontWeight: isParent ? FontWeight.w700 : FontWeight.w500, color: HomeStyle.text(context))),
              const SizedBox(height: 5),
              Text('${money > 0 ? '+' : ''}${HomeStyle.money(context, money)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: money < 0 ? HomeStyle.danger : HomeStyle.accent(context))),
            ])),
            const SizedBox(width: 8),
            Icon(isParent ? (isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded)
              : Icons.chevron_right_rounded, color: HomeStyle.muted(context)),
          ])),
      ),
    ),
  );
}

class HomeLoadingList extends StatelessWidget {
  const HomeLoadingList({Key? key, this.embedded = false}) : super(key: key);
  final bool embedded;
  @override
  Widget build(BuildContext context) => ListView.separated(
    shrinkWrap: embedded, physics: embedded ? const NeverScrollableScrollPhysics() : null,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), itemCount: 5,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, __) => Container(padding: const EdgeInsets.all(16),
      decoration: HomeStyle.decoration(context),
      child: Shimmer.fromColors(baseColor: HomeStyle.background(context),
        highlightColor: HomeStyle.teal.withOpacity(.18),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 14, width: 140, color: Colors.white), const SizedBox(height: 10),
            Container(height: 12, width: 90, color: Colors.white),
          ])),
        ])),
    ),
  );
}
