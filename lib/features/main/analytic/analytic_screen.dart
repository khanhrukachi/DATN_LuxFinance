import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_page_loading.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:personal_financial_management/core/constants/function/get_date.dart';
import 'package:personal_financial_management/core/constants/function/get_data_spending.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/main/analytic/chart/column_chart.dart';
import 'package:personal_financial_management/features/main/analytic/chart/pie_chart.dart';
import 'package:personal_financial_management/features/main/analytic/search/search_screen.dart';
import 'package:personal_financial_management/features/main/analytic/widget/custom_tabbar.dart';
import 'package:personal_financial_management/features/main/analytic/widget/show_date.dart';
import 'package:personal_financial_management/features/main/analytic/widget/show_list_spending_column.dart';
import 'package:personal_financial_management/features/main/analytic/widget/show_list_spending_pie.dart';
import 'package:personal_financial_management/features/main/analytic/widget/tabbar_chart.dart';
import 'package:personal_financial_management/features/main/analytic/widget/tabbar_type.dart';
import 'package:personal_financial_management/features/main/analytic/widget/total_report.dart';

class AnalyticPage extends StatefulWidget {
  const AnalyticPage({Key? key}) : super(key: key);

  @override
  State<AnalyticPage> createState() => _AnalyticPageState();
}

class _AnalyticPageState extends State<AnalyticPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _chartController;
  late TabController _typeController;

  bool chart = false;
  DateTime now = DateTime.now();
  String date = "";

  @override
  void initState() {
    super.initState();

    date = getWeek(now);

    _tabController = TabController(length: 3, vsync: this);
    _chartController = TabController(length: 2, vsync: this);
    _typeController = TabController(length: 2, vsync: this);

    _tabController.addListener(_onTabChange);
    _chartController.addListener(() {
      setState(() => chart = _chartController.index == 1);
    });
    _typeController.addListener(() => setState(() {}));
  }

  void _onTabChange() {
    setState(() {
      now = DateTime.now();
      if (_tabController.index == 0) {
        date = getWeek(now);
      } else if (_tabController.index == 1) {
        date = getMonth(now);
      } else {
        date = getYear(now);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chartController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  bool checkDate(DateTime dateTime) {
    if (_tabController.index == 0) {
      int weekDay = now.weekday;
      DateTime firstDay =
      DateTime(now.year, now.month, now.day).subtract(
        Duration(days: weekDay - 1),
      );
      DateTime lastDay = firstDay.add(const Duration(days: 6));

      return (dateTime.isAfter(firstDay) && dateTime.isBefore(lastDay)) ||
          isSameDay(dateTime, firstDay) ||
          isSameDay(dateTime, lastDay);
    }

    if (_tabController.index == 1) {
      return isSameMonth(dateTime, now);
    }

    return dateTime.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnalyticStyle.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AnalyticStyle.background(context),
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text(
          AppLocalizations.of(context).translate('spending'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
            child: Material(color: AnalyticStyle.teal.withOpacity(.10),
              borderRadius: BorderRadius.circular(14), clipBehavior: Clip.antiAlias,
              child: IconButton(icon: Icon(Icons.search_rounded, color: AnalyticStyle.accent(context)),
                  onPressed: () => Navigator.of(context).push(createRoute(
                      screen: const SearchPage(), begin: const Offset(1, 0)))),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: CustomTabBar(controller: _tabController),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Center(child: Text(AppLocalizations.of(context).translate('no_data')));
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("data")
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(
            AppLocalizations.of(context).translate('something_went_wrong')));
        if (!snapshot.hasData) {
          return const AnalyticPageLoading(itemCount: 6);
        }

        Map<String, dynamic> data = {};
        if (snapshot.data!.data() != null) {
          data = snapshot.data!.data() as Map<String, dynamic>;
        }

        final ids = getDataSpending(
          data: data,
          index: _tabController.index,
          date: now,
        );

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("spending").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text(
                AppLocalizations.of(context).translate('something_went_wrong')));
            if (!snapshot.hasData) {
              return const AnalyticPageLoading(itemCount: 6);
            }

            final spendingList = snapshot.data!.docs
                .where((e) => ids.contains(e.id))
                .map((e) => Spending.fromFirebase(e))
                .where((e) => checkDate(e.dateTime))
                .toList();

            final classify = spendingList.where((e) {
              if (_typeController.index == 0 && e.money > 0) return false;
              if (_typeController.index == 1 && e.money < 0) return false;
              return true;
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  _showChart(classify),
                  if (spendingList.isNotEmpty)
                    TotalReport(list: spendingList),
                  chart
                      ? showListSpendingPie(list: classify)
                      : ShowListSpendingColumn(
                    spendingList: classify,
                    index: _tabController.index,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _showChart(List<Spending> list) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: AnalyticStyle.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AnalyticStyle.teal.withOpacity(.16))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          showDate(
            date: date,
            index: _tabController.index,
            now: now,
            action: (d, n) {
              setState(() {
                date = d;
                now = n;
              });
            },
          ),

          TabBarType(controller: _typeController),

          list.isNotEmpty
              ? (chart
              ? MyPieChart(list: list)
              : ColumnChart(
            index: _tabController.index,
            list: list,
            dateTime: now,
          ))
              : _emptyChart(),

          tabBarChart(controller: _chartController),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _emptyChart() {
    final theme = Theme.of(context);

    return SizedBox(
      height: 295,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_chart_outlined,
            size: 40,
            color: AnalyticStyle.accent(context),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('no_data'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AnalyticStyle.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}
