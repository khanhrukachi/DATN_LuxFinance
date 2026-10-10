import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/main/home/view_list_spending_screen.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';
Widget showListSpendingPie({required List<Spending> list}) {
  final total = list.fold<int>(0, (s, e) => s + e.money.abs());
  return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    itemCount: listType.length,
    itemBuilder: (context, index) {
      if ([0, 10, 21, 27, 35, 38].contains(index)) return const SizedBox.shrink();
      final items = list.where((e) => e.type == index).toList();
      if (items.isEmpty) return const SizedBox.shrink();
      final sum = items.fold<int>(0, (s, e) => s + e.money);
      final share = total == 0 ? 0.0 : items.fold<int>(0, (s, e) => s + e.money.abs()) / total;
      return Container(margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(4), decoration: AnalyticStyle.decoration(context),
        child: AnalyticCategoryRow(
          title: AppLocalizations.of(context).translate(listType[index]['title'] ?? 'other'),
          image: listType[index]['image'], amount: sum, share: share,
          color: AnalyticStyle.palette[index % AnalyticStyle.palette.length],
          onTap: () => Navigator.of(context).push(createRoute(
              screen: ViewListSpendingPage(spendingList: items), begin: const Offset(1, 0))),
        ),
      );
    },
  );
}
