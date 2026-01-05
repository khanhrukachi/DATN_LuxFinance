import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_page_loading.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:personal_financial_management/core/constants/function/get_date.dart';
import 'package:personal_financial_management/core/constants/function/get_data_spending.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/main/analytic/chart/column_chart.dart';
import 'package:personal_financial_management/features/main/analytic/chart/pie_chart.dart';
import 'package:personal_financial_management/features/main/analytic/search_screen.dart';
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

class _AnalyticPageState extends State<AnalyticPage> with TickerProviderStateMixin {
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
      DateTime firstDay = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekDay - 1));
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          AppLocalizations.of(context).translate('spending'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(90),
              onTap: () {
                Navigator.of(context).push(
                  createRoute(
                    screen: const SearchPage(),
                    begin: const Offset(1, 0),
                  ),
                );
              },
              child: Material(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(90),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(90),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.magnifyingGlass,
                    size: 20,
                    color: Color.fromRGBO(180, 190, 190, 1),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: CustomTabBar(controller: _tabController),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("data")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AnalyticPageLoading(itemCount: 6);
        }

        Map<String, dynamic> data = {};
        if (snapshot.data!.data() != null) {
          data = snapshot.data!.data() as Map<String, dynamic>;
        }

        final ids = getDataSpending(data: data, index: _tabController.index, date: now);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("spending").snapshots(),
          builder: (context, snapshot) {
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

            if (spendingList.isEmpty) {
              return _noData(context);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _showChart(classify),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: isDark ? Colors.white10 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              ? chart
              ? MyPieChart(list: list)
              : ColumnChart(index: _tabController.index, list: list, dateTime: now)
              : _noData(context),
          tabBarChart(controller: _chartController),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _noData(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        elevation: 0.5,
        color: isDark ? Colors.white10 : Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          height: 240,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.15),
                ),
                child: Icon(
                  Icons.insert_chart_outlined_rounded,
                  size: 36,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).translate('no_data'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
