import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
class TotalReport extends StatelessWidget {
  const TotalReport({Key? key, required this.list}) : super(key: key);
  final List<Spending> list;
  @override
  Widget build(BuildContext context) {
    final income = list.where((e) => e.money > 0).fold<int>(0, (s, e) => s + e.money);
    final spending = list.where((e) => e.money < 0).fold<int>(0, (s, e) => s + e.money);
    final revenue = income + spending;
    final tr = AppLocalizations.of(context);
    return Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.all(14),
      decoration: AnalyticStyle.decoration(context, hero: true),
      child: Column(children: [
        _item(context, tr.translate('revenue_expenditure'), revenue,
            Icons.account_balance_wallet_outlined, revenue < 0 ? AnalyticStyle.danger : AnalyticStyle.accent(context)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final a = _item(context, tr.translate('income'), income, Icons.south_west_rounded, AnalyticStyle.accent(context));
          final b = _item(context, tr.translate('spending'), spending, Icons.north_east_rounded, AnalyticStyle.danger);
          if (constraints.maxWidth < 240 || MediaQuery.of(context).textScaleFactor > 1.4)
            return Column(children: [a, const SizedBox(height: 8), b]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
        }),
      ]),
    );
  }
  Widget _item(BuildContext context, String title, int amount, IconData icon, Color color) => Container(
    width: double.infinity, padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(color: AnalyticStyle.card(context).withOpacity(.65),
        borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(.12))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6),
        Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: AnalyticStyle.muted(context))))]),
      const SizedBox(height: 5),
      SizedBox(width: double.infinity, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(AnalyticStyle.money(context, amount), style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.w700, color: color)))),
    ]),
  );
}
