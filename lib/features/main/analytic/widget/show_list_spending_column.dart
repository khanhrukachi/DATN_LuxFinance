import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/function/get_data_spending.dart';
import 'package:personal_financial_management/core/constants/function/get_date.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/main/home/view_list_spending_screen.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/bloc/setting_cubit.dart';
import 'package:personal_financial_management/setting/bloc/setting_state.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

class ShowListSpendingColumn extends StatefulWidget {
  const ShowListSpendingColumn({
    Key? key,
    required this.spendingList,
    required this.index,
  }) : super(key: key);

  final List<Spending> spendingList;
  final int index;

  @override
  State<ShowListSpendingColumn> createState() =>
      _ShowListSpendingColumnState();
}

class _ShowListSpendingColumnState extends State<ShowListSpendingColumn> {

  @override
  Widget build(BuildContext context) {
    if (widget.spendingList.isEmpty) {
      return const SizedBox.shrink();
    }

    final listDate = widget.index == 0
        ? getListDayOfWeek(widget.spendingList.first.dateTime)
        : widget.index == 1
        ? getListWeekOfMonth(widget.spendingList.first.dateTime)
        : getListMonthOfYear(widget.spendingList.first.dateTime);

    return BlocBuilder<SettingCubit, SettingState>(
      builder: (_, settingState) {
        return _buildBody(listDate, settingState.locale.languageCode);
      },
    );
  }

  Widget _buildBody(List<DateTime> listDate, String lang) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listDate.length,
      itemBuilder: (context, index) {
        final list = widget.index == 0
            ? widget.spendingList
            .where((e) => isSameDay(e.dateTime, listDate[index]))
            .toList()
            : widget.index == 1
            ? widget.spendingList
            .where((e) => checkOnWeek(listDate[index], e.dateTime))
            .toList()
            : widget.spendingList
            .where((e) => isSameMonth(e.dateTime, listDate[index]))
            .toList();

        if (list.isEmpty) return const SizedBox.shrink();

        final totalMoney = list.fold<double>(0, (sum, e) => sum + e.money);

        return Container(margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14), decoration: AnalyticStyle.decoration(context),
          child: Column(children: [
            Row(children: [
              Container(width: 42, height: 42, alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: AnalyticStyle.gradient, borderRadius: BorderRadius.circular(13)),
                  child: Text(widget.index == 0 ? DateFormat('dd').format(listDate[index])
                      : '${index + 1}'.padLeft(2, '0'),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AnalyticStyle.ink))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.index == 0 ? DateFormat.EEEE(lang).format(listDate[index])
                    : '${AppLocalizations.of(context).translate(widget.index == 1 ? 'week' : 'month')} ${index + 1}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(DateFormat.yMMMM(lang).format(listDate[index]),
                    style: TextStyle(fontSize: 12, color: AnalyticStyle.muted(context))),
                const SizedBox(height: 4),
                Text(AnalyticStyle.money(context, totalMoney), style: TextStyle(fontWeight: FontWeight.w600,
                    color: totalMoney < 0 ? AnalyticStyle.danger : AnalyticStyle.accent(context))),
              ])),
            ]),
            const SizedBox(height: 12),
            _buildItem(list, totalMoney),
          ]),
        );
      },
    );
  }

  Widget _buildItem(List<Spending> listSpending, double totalMoney) => Column(
    children: List.generate(listType.length, (index) {
      final items = listSpending.where((e) => e.type == index).toList();
      if (items.isEmpty) return const SizedBox.shrink();
      final amount = items.fold<int>(0, (s, e) => s + e.money);
      return Padding(padding: const EdgeInsets.only(bottom: 8),
        child: AnalyticCategoryRow(
          title: AppLocalizations.of(context).translate(listType[index]['title'] ?? 'other'),
          image: listType[index]['image'], amount: amount,
          share: totalMoney == 0 ? 0.0 : amount / totalMoney,
          color: AnalyticStyle.accent(context),
          onTap: () => Navigator.of(context).push(createRoute(
              screen: ViewListSpendingPage(spendingList: items), begin: const Offset(1, 0))),
        ),
      );
    }),
  );
}
