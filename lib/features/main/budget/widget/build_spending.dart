import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/view_spending/view_spending_page.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';
import 'package:shimmer/shimmer.dart';

class BuildSpending extends StatelessWidget {
  const BuildSpending({Key? key, this.spendingList, this.date, this.change}) : super(key: key);
  final List<Spending>? spendingList;
  final DateTime? date;
  final Function(Spending spending)? change;
  @override
  Widget build(BuildContext context) {
    if (spendingList == null) return loadingItemSpending();
    if (spendingList!.isEmpty) return Container(
      width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(24), decoration: BudgetStyle.decoration(context),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined, color: BudgetStyle.accent(context), size: 38),
        const SizedBox(height: 12),
        Text('${AppLocalizations.of(context).translate('you_have_spending_the_day')} '
            '${DateFormat('dd/MM/yyyy').format(date ?? DateTime.now())}',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5,
                color: BudgetStyle.muted(context))),
      ]),
    );
    return showListSpending(context, spendingList!);
  }
  Widget showListSpending(BuildContext context, List<Spending> spendingList) {
    final format = NumberFormat.currency(
        locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US',
        symbol: '₫', decimalDigits: 0);
    return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: spendingList.length,
      itemBuilder: (context, index) {
        final spending = spendingList[index];
        final data = spending.type >= 0 && spending.type < listType.length
            ? listType[spending.type] : <String, dynamic>{};
        final image = data['image']?.toString();
        final name = spending.type == 41 ? (spending.typeName ?? '')
            : AppLocalizations.of(context).translate(data['title']?.toString() ?? 'other');
        final accent = spending.money < 0 ? BudgetStyle.danger : BudgetStyle.accent(context);
        return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Material(
          color: BudgetStyle.card(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: BudgetStyle.teal.withOpacity(.12))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: () => Navigator.of(context).push(createRoute(
              screen: ViewSpendingPage(spending: spending, change: (value) {
                if (change != null) change!(value);
              }), begin: const Offset(1, 0))),
            child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Container(width: 44, height: 44, padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: BudgetStyle.teal.withOpacity(.10),
                      borderRadius: BorderRadius.circular(14)),
                  child: image == null || image.isEmpty
                      ? Icon(Icons.receipt_long_outlined, color: BudgetStyle.accent(context))
                      : Image.asset(image, errorBuilder: (_, __, ___) =>
                      Icon(Icons.category_outlined, color: BudgetStyle.accent(context)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                    color: BudgetStyle.text(context))),
                const SizedBox(height: 5),
                Text(format.format(spending.money), style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: accent)),
              ])),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: BudgetStyle.accent(context), size: 22),
            ])),
          ),
        ));
      },
    );
  }
  Widget loadingItemSpending() => Builder(builder: (context) => ListView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 6,
    itemBuilder: (_, __) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Shimmer.fromColors(baseColor: BudgetStyle.card(context),
            highlightColor: BudgetStyle.dark(context) ? const Color(0xFF25434B) : const Color(0xFFE1F7F4),
            child: Container(height: 80, decoration: BoxDecoration(color: BudgetStyle.card(context),
                borderRadius: BorderRadius.circular(20))))),
  ));
}
