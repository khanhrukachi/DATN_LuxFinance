import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/function/list_categories.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:table_calendar/table_calendar.dart';

class ItemSpendingDay extends StatelessWidget {
  const ItemSpendingDay({
    Key? key,
    required this.spendingList,
    required this.type,
  }) : super(key: key);

  final List<Spending> spendingList;
  final int type;

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.currency(locale: "vi_VI");

    spendingList.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final listDate = spendingList
        .map((e) => DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day))
        .toSet()
        .toList();

    return ListView.builder(
      itemCount: listDate.length,
      itemBuilder: (context, index) {
        final date = listDate[index];

        final list = spendingList
            .where((e) => isSameDay(e.dateTime, date))
            .toList();

        final totalMoney =
        list.fold<double>(0, (sum, e) => sum + e.money);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Row(
                    children: [
                      Text(
                        date.day.toString(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat("EEEE").format(date),
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            DateFormat("MMMM, yyyy").format(date),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        numberFormat.format(totalMoney),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                /// ===== LIST SPENDING =====
                Column(
                  children: list.map((spending) {
                    final data = type == 0
                        ? categories[spending.type]
                        : income[spending.type];

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Image.asset(
                              data["icon"]!,
                              width: 36,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)
                                    .translate(data["name"]!),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              numberFormat.format(spending.money),
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
