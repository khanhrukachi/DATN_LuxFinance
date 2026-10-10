
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/home/widget/home_style.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'package:personal_financial_management/models/spending.dart';
import 'widget/item_spending_day.dart';

class ViewListSpendingPage extends StatelessWidget {
  const ViewListSpendingPage({Key? key, required this.spendingList})
      : super(key: key);
  final List<Spending> spendingList;

  @override
  Widget build(BuildContext context) {
    final first = spendingList.isEmpty ? null : spendingList.first;
    final config = first != null && first.type >= 0 && first.type < listType.length ? listType[first.type] : null;
    final title = first == null ? AppLocalizations.of(context).translate('spending_list')
        : first.type == 41 || first.categoryId == 'custom' ? (first.typeName ?? '')
        : AppLocalizations.of(context).translate(config?['title'] ?? 'other');
    return Scaffold(backgroundColor: HomeStyle.background(context),
      appBar: AppBar(elevation: 0, backgroundColor: HomeStyle.background(context),
          centerTitle: false, title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      body: ItemSpendingDay(spendingList: spendingList),
    );
  }
}
