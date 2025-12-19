import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/bloc/setting_cubit.dart';
import 'package:personal_financial_management/setting/bloc/setting_state.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/view_spending/view_spending_page.dart';

class ItemSpendingDay extends StatefulWidget {
  const ItemSpendingDay({Key? key, required this.spendingList})
      : super(key: key);

  final List<Spending> spendingList;

  @override
  State<ItemSpendingDay> createState() => _ItemSpendingDayState();
}

class _ItemSpendingDayState extends State<ItemSpendingDay> {
  final NumberFormat numberFormat =
  NumberFormat.currency(locale: "vi_VI", symbol: "₫");

  @override
  Widget build(BuildContext context) {
    widget.spendingList.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final List<DateTime> listDate = widget.spendingList
        .map((e) => DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day))
        .toSet()
        .toList();

    if (listDate.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).translate('no_data'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return BlocBuilder<SettingCubit, SettingState>(
      builder: (_, settingState) {
        return _buildBody(listDate, settingState.locale.languageCode);
      },
    );
  }

  Widget _buildBody(List<DateTime> listDate, String lang) {
    return ListView.builder(
      itemCount: listDate.length,
      itemBuilder: (context, index) {
        final List<Spending> list = widget.spendingList
            .where((e) => isSameDay(e.dateTime, listDate[index]))
            .toList();

        final int totalMoney =
        list.fold<int>(0, (sum, e) => sum + e.money);

        return Padding(
          padding: const EdgeInsets.all(10),
          child: Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                _header(listDate[index], totalMoney, lang),
                const Divider(height: 2),
                _listItem(list),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(DateTime date, int totalMoney, String lang) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Text(
            DateFormat("dd").format(date),
            style: const TextStyle(fontSize: 30),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat.EEEE(lang).format(date)),
              Text(DateFormat.yMMMM(lang).format(date)),
            ],
          ),
          const Spacer(),
          Text(
            numberFormat.format(totalMoney),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _listItem(List<Spending> list) {
    return Column(
      children: List.generate(list.length, (index) {
        final Spending spending = list[index];

        final typeConfig = listType[spending.type];
        final String? imagePath = typeConfig?["image"];
        final String? titleKey = typeConfig?["title"];

        return InkWell(
          onTap: () => _onTapItem(spending),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                imagePath != null
                    ? Image.asset(imagePath, width: 40)
                    : const Icon(Icons.money_rounded, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    spending.type == 41
                        ? (spending.typeName ?? '')
                        : AppLocalizations.of(context)
                        .translate(titleKey ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  numberFormat.format(spending.money),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _onTapItem(Spending spending) async {
    try {
      if (spending.id == null) {
        throw Exception("Spending ID is null");
      }

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
                widget.spendingList
                    .removeWhere((e) => e.id == updated.id);
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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate('cannot_open_spending'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
