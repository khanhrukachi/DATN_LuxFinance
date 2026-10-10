import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
import 'package:personal_financial_management/core/constants/function/get_date.dart';
Widget showDate({required String date, required int index, required DateTime now,
  required Function(String, DateTime) action}) => Builder(builder: (context) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8),
  child: Row(children: [
    IconButton(icon: Icon(Icons.chevron_left_rounded, color: AnalyticStyle.accent(context)),
        onPressed: () => _movePeriod(index, now, -1, action)),
    Expanded(child: Text(date, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AnalyticStyle.text(context)))),
    IconButton(icon: Icon(Icons.chevron_right_rounded, color: AnalyticStyle.accent(context)),
        onPressed: () => _movePeriod(index, now, 1, action)),
  ]),
));
void _movePeriod(int index, DateTime now, int step, Function(String, DateTime) action) {
  if (index == 0) {
    final next = now.add(Duration(days: 7 * step)); action(getWeek(next), next);
  } else if (index == 1) {
    final next = DateTime(now.year, now.month + step); action(getMonth(next), next);
  } else {
    final next = DateTime(now.year + step, now.month); action(getYear(next), next);
  }
}
