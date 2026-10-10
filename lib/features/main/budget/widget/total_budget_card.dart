import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';

class TotalBudgetCard extends StatelessWidget {
  const TotalBudgetCard({Key? key, required this.spent, required this.limit,
    required this.progress, this.isLoading = false}) : super(key: key);
  final double spent, limit, progress;
  final bool isLoading;
  @override
  Widget build(BuildContext context) {
    final p = progress.isFinite ? progress.clamp(0.0, double.infinity).toDouble() : 0.0;
    final accent = BudgetStyle.status(context, p);
    final tr = AppLocalizations.of(context);
    final format = NumberFormat.currency(
        locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US',
        symbol: '₫', decimalDigits: 0);
    if (isLoading) return Padding(padding: const EdgeInsets.all(16), child: Shimmer.fromColors(
        baseColor: BudgetStyle.card(context),
        highlightColor: BudgetStyle.dark(context) ? const Color(0xFF25434B) : const Color(0xFFE1F7F4),
        child: Container(height: 190, decoration: BoxDecoration(
            color: BudgetStyle.card(context), borderRadius: BorderRadius.circular(26)))));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BudgetStyle.decoration(context, hero: true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(gradient: BudgetStyle.gradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.account_balance_wallet_outlined, color: BudgetStyle.ink)),
          const SizedBox(width: 12),
          Expanded(child: Text(tr.translate('budget_this_month'), style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: BudgetStyle.text(context)))),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: Text(format.format(limit), style: TextStyle(
              fontSize: 27, fontWeight: FontWeight.w700, color: BudgetStyle.text(context)))),
          const SizedBox(width: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: accent.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
              child: Text('${(p * 100).toStringAsFixed(0)}%', style: TextStyle(
                  color: accent, fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Text('${tr.translate('spent')}: ${format.format(spent)}', style: TextStyle(
            fontSize: 13, color: BudgetStyle.muted(context))),
        const SizedBox(height: 18),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(
            value: p.clamp(0.0, 1.0).toDouble(), minHeight: 9,
            backgroundColor: BudgetStyle.text(context).withOpacity(.07),
            valueColor: AlwaysStoppedAnimation<Color>(accent))),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 6, children: [
          Text(tr.translate('remaining'), style: TextStyle(color: BudgetStyle.muted(context), fontSize: 13)),
          Text(format.format(limit - spent), style: TextStyle(
              color: accent, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}
