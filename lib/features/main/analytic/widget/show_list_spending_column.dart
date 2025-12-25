import 'package:flutter/material.dart';
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
  final numberFormat = NumberFormat.currency(locale: "vi_VI");

  @override
  Widget build(BuildContext context) {
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            shadowColor: Colors.black26,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          widget.index == 0
                              ? DateFormat("dd").format(listDate[index])
                              : (index + 1).toString().padLeft(2, '0'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.index == 0
                                  ? DateFormat.EEEE(lang)
                                  .format(listDate[index])
                                  : "${AppLocalizations.of(context).translate(widget.index == 1 ? "week" : "month")} ${index + 1}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.yMMMM(lang).format(listDate[index]),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        numberFormat.format(totalMoney),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _buildItem(list, totalMoney),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(List<Spending> listSpending, double totalMoney) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: List.generate(listType.length, (index) {
        final list =
        listSpending.where((e) => e.type == index).toList();
        if (list.isEmpty) return const SizedBox.shrink();

        final typeMoney = list.fold<double>(0, (sum, e) => sum + e.money);
        final progress = totalMoney == 0 ? 0.0 : (typeMoney / totalMoney);

        final Map<String, dynamic> typeItem = listType[index];
        final String titleKey = typeItem['title'] ?? 'other';
        final String? imagePath = typeItem['image'];
        Color mainColor;
        if (typeMoney > 0) {
          mainColor = Colors.green.shade400;
        } else if (typeMoney < 0) {
          mainColor = Colors.red.shade400;
        } else {
          mainColor = Colors.grey; // bằng 0
        }

        final Color textPrimary = isDark ? Colors.white : Colors.black87;
        final Color textSecondary = Colors.grey.shade700;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              createRoute(
                screen: ViewListSpendingPage(spendingList: list),
                begin: const Offset(1, 0),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            mainColor.withOpacity(0.3),
                            mainColor.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: imagePath != null
                          ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(imagePath),
                      )
                          : Icon(Icons.category, color: mainColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).translate(titleKey),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      numberFormat.format(typeMoney),
                      style: TextStyle(fontSize: 14, color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                    isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
