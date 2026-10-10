import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';

// Retain the existing top-level helper signature for callers.
Widget shimmerAnimation() => Shimmer.fromColors(
  baseColor: const Color(0xFF25434B), highlightColor: const Color(0xFF3B6269),
  child: Container(height: 20, width: 90, decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(6))),
);

class TotalSpending extends StatelessWidget {
  const TotalSpending({Key? key, this.list}) : super(key: key);
  final List<Spending>? list;
  @override
  Widget build(BuildContext context) {
    var income = 0;
    var expense = 0;
    for (final item in list ?? <Spending>[]) {
      if (item.money > 0) income += item.money;
      if (item.money < 0) expense += item.money;
    }
    final tr = AppLocalizations.of(context);
    final format = NumberFormat.currency(
        locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US',
        symbol: '₫', decimalDigits: 0);
    Widget metric(String key, int value, Color color, IconData icon) => Expanded(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 8),
            Text(tr.translate(key), textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: BudgetStyle.muted(context))),
            const SizedBox(height: 6),
            if (list == null)
              Shimmer.fromColors(baseColor: BudgetStyle.card(context),
                  highlightColor: BudgetStyle.dark(context) ? const Color(0xFF25434B) : const Color(0xFFE1F7F4),
                  child: Container(height: 18, width: 70, color: Colors.white))
            else Text(format.format(value), textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ])),
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BudgetStyle.decoration(context),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        metric('income', income, BudgetStyle.accent(context), Icons.south_west_rounded),
        metric('spending', expense, BudgetStyle.danger, Icons.north_east_rounded),
        metric('total', income + expense, BudgetStyle.text(context), Icons.account_balance_wallet_outlined),
      ]),
    );
  }
}
