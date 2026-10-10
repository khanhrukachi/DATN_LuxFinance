import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';

class BudgetItem extends StatelessWidget {
  const BudgetItem({Key? key, required this.type, required this.spent,
    required this.limit, required this.progress, this.onTap, this.isLoading = false}) : super(key: key);
  final int type, spent, limit;
  final double progress;
  final VoidCallback? onTap;
  final bool isLoading;
  @override
  Widget build(BuildContext context) {
    if (isLoading) return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Shimmer.fromColors(
        baseColor: BudgetStyle.card(context),
        highlightColor: BudgetStyle.dark(context) ? const Color(0xFF25434B) : const Color(0xFFE1F7F4),
        child: Container(height: 106, decoration: BoxDecoration(
            color: BudgetStyle.card(context), borderRadius: BorderRadius.circular(20))),
      ),
    );
    final item = type >= 0 && type < listType.length ? listType[type] : <String, dynamic>{};
    final image = item['image']?.toString();
    final p = progress.isFinite ? progress.clamp(0.0, double.infinity).toDouble() : 0.0;
    final color = BudgetStyle.status(context, p);
    final format = NumberFormat.currency(
        locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US',
        symbol: '₫', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(color: BudgetStyle.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: color.withOpacity(.18))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, splashColor: BudgetStyle.teal.withOpacity(.12),
          child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Container(width: 46, height: 46, padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
                child: image == null || image.isEmpty
                    ? Icon(Icons.category_outlined, color: color)
                    : Image.asset(image, errorBuilder: (_, __, ___) => Icon(Icons.category_outlined, color: color))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(AppLocalizations.of(context).translate(item['title']?.toString() ?? 'other'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BudgetStyle.text(context)))),
                const SizedBox(width: 8),
                Text('${(p * 100).toStringAsFixed(0)}%', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
                  value: p.clamp(0.0, 1.0).toDouble(), minHeight: 7,
                  backgroundColor: BudgetStyle.text(context).withOpacity(.07),
                  valueColor: AlwaysStoppedAnimation<Color>(color))),
              const SizedBox(height: 8),
              Text('${format.format(spent)} / ${format.format(limit)}',
                  style: TextStyle(fontSize: 12, height: 1.5, color: BudgetStyle.muted(context))),
            ])),
            const SizedBox(width: 8),
            Icon(p >= 1 ? Icons.warning_rounded : p >= .8 ? Icons.warning_amber_rounded
                : Icons.chevron_right_rounded, color: color, size: 22),
          ])),
        ),
      ),
    );
  }
}
