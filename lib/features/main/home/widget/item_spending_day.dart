import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/home/widget/home_style.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/bloc/setting_cubit.dart';
import 'package:personal_financial_management/setting/bloc/setting_state.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/view_spending/view_spending_page.dart';
import 'package:table_calendar/table_calendar.dart';

class ItemSpendingDay extends StatefulWidget {
  const ItemSpendingDay({Key? key, required this.spendingList}) : super(key: key);
  final List<Spending> spendingList;

  @override
  State<ItemSpendingDay> createState() => _ItemSpendingDayState();
}

class _ItemSpendingDayState extends State<ItemSpendingDay> {

  @override
  Widget build(BuildContext context) {
    final sortedSpendings = List<Spending>.from(widget.spendingList)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final dates = sortedSpendings
        .map((e) => DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day))
        .toSet()
        .toList();

    if (dates.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).translate('no_data'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return BlocBuilder<SettingCubit, SettingState>(
      builder: (_, settingState) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: dates.length,
          itemBuilder: (context, index) {
            final date = dates[index];

            final list = sortedSpendings
                .where((e) => isSameDay(e.dateTime, date))
                .toList();

            final total = list.fold<int>(0, (sum, e) => sum + e.money);

            return _dayCard(date, total, list, settingState.locale.languageCode);
          },
        );
      },
    );
  }

  Widget _dayCard(DateTime date, int total, List<Spending> list, String lang) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Material(color: HomeStyle.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: HomeStyle.teal.withOpacity(.16))),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 46, height: 46, alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: HomeStyle.gradient, borderRadius: BorderRadius.circular(14)),
                  child: Text(DateFormat('dd').format(date),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HomeStyle.ink))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat.EEEE(lang).format(date), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(DateFormat.yMMMM(lang).format(date), style: TextStyle(fontSize: 12, color: HomeStyle.muted(context))),
                const SizedBox(height: 4),
                Text(HomeStyle.money(context, total), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: total < 0 ? HomeStyle.danger : HomeStyle.accent(context))),
              ])),
            ])),
        Divider(height: 1, color: HomeStyle.teal.withOpacity(.12)),
        ...list.map(_itemRow),
      ]),
    ),
  );

  Widget _itemRow(Spending spending) {
    final config = spending.type >= 0 && spending.type < listType.length ? listType[spending.type] : null;
    return InkWell(onTap: () => _onTapItem(spending),
      child: Padding(padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 40, height: 40, padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: HomeStyle.teal.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                child: config?['image'] == null ? Icon(Icons.label_outline_rounded, color: HomeStyle.accent(context))
                    : Image.asset(config!['image']!, errorBuilder: (_, __, ___) => Icon(Icons.label_outline_rounded, color: HomeStyle.accent(context)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(spending.type == 41 || spending.categoryId == 'custom' ? (spending.typeName ?? '')
                  : AppLocalizations.of(context).translate(config?['title'] ?? 'other'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(HomeStyle.money(context, spending.money), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: spending.money < 0 ? HomeStyle.danger : HomeStyle.accent(context))),
            ])),
            const SizedBox(width: 8),
            Text(DateFormat('HH:mm').format(spending.dateTime), style: TextStyle(fontSize: 12, color: HomeStyle.muted(context))),
          ])),
    );
  }

  Future<void> _onTapItem(Spending spending) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewSpendingPage(
          spending: spending,
          change: (updated) async {
            try {
              updated.image = await FirebaseStorage.instance
                  .ref("spending/${updated.id}.png")
                  .getDownloadURL();
            } catch (_) {}

            if (!mounted) return;
            setState(() {
              widget.spendingList.removeWhere((e) => e.id == updated.id);
              widget.spendingList.add(updated);
            });
          },
          delete: (id) {
            if (!mounted) return;
            setState(() {
              widget.spendingList.removeWhere((e) => e.id == id);
            });
          },
        ),
      ),
    );
  }
}
