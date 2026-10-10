import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/setting/bloc/setting_cubit.dart';
import 'package:personal_financial_management/setting/bloc/setting_state.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';
import 'package:table_calendar/table_calendar.dart';

bool isSameMonth(DateTime day1, DateTime day2) =>
    day1.year == day2.year && day1.month == day2.month;
BorderSide customBorderSide() => BorderSide(color: BudgetStyle.teal.withOpacity(.10));

class CustomTableCalendar extends StatelessWidget {
  const CustomTableCalendar({Key? key, required this.focusedDay,
    required this.selectedDay, this.dataSpending, this.onPageChanged, this.onDaySelected}) : super(key: key);
  final DateTime focusedDay, selectedDay;
  final List<Spending>? dataSpending;
  final Function(DateTime)? onPageChanged;
  final Function(DateTime, DateTime)? onDaySelected;
  @override
  Widget build(BuildContext context) => BlocBuilder<SettingCubit, SettingState>(
    buildWhen: (previous, current) => previous != current,
    builder: (context, settingState) => Container(
      decoration: BudgetStyle.decoration(context),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: TableCalendar<Spending>(
        locale: settingState.locale.languageCode,
        firstDay: DateTime.utc(2000), lastDay: DateTime.utc(2100),
        focusedDay: focusedDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        onPageChanged: (day) { if (onPageChanged != null) onPageChanged!(day); },
        onDaySelected: (selected, focused) {
          if (!isSameDay(selectedDay, selected) && isSameMonth(focusedDay, selected)
              && onDaySelected != null) onDaySelected!(selected, focused);
        },
        eventLoader: (day) => dataSpending?.where((item) => isSameDay(item.dateTime, day)).toList() ?? [],
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(5),
          defaultTextStyle: TextStyle(color: BudgetStyle.text(context)),
          weekendTextStyle: TextStyle(color: BudgetStyle.accent(context)),
          selectedDecoration: BoxDecoration(gradient: BudgetStyle.gradient,
              borderRadius: BorderRadius.circular(12)),
          selectedTextStyle: const TextStyle(color: BudgetStyle.ink, fontWeight: FontWeight.w700),
          todayDecoration: BoxDecoration(color: BudgetStyle.teal.withOpacity(.12),
              borderRadius: BorderRadius.circular(12), border: Border.all(color: BudgetStyle.teal.withOpacity(.4))),
          todayTextStyle: TextStyle(color: BudgetStyle.accent(context), fontWeight: FontWeight.w700),
          defaultDecoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          weekendDecoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false, titleCentered: true,
          headerPadding: const EdgeInsets.symmetric(vertical: 8),
          headerMargin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(gradient: BudgetStyle.gradient, borderRadius: BorderRadius.circular(16)),
          titleTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: BudgetStyle.ink),
          leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: BudgetStyle.ink),
          rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: BudgetStyle.ink),
        ),
        calendarBuilders: CalendarBuilders<Spending>(
          markerBuilder: (context, day, events) {
            if (events.isEmpty || !isSameMonth(focusedDay, day)) return const SizedBox.shrink();
            return Positioned(bottom: 1, right: 3, child: Container(
              constraints: const BoxConstraints(minWidth: 16), height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center,
              decoration: BoxDecoration(color: BudgetStyle.card(context),
                  borderRadius: BorderRadius.circular(8), border: Border.all(color: BudgetStyle.teal.withOpacity(.4))),
              child: Text(events.length > 99 ? '99+' : '${events.length}',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: BudgetStyle.accent(context))),
            ));
          },
          dowBuilder: (context, day) => Center(child: Text(
            DateFormat.E(settingState.locale.languageCode).format(day),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: day.weekday >= DateTime.saturday ? BudgetStyle.accent(context) : BudgetStyle.muted(context)),
          )),
        ),
      ),
    ),
  );
}
