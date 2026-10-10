import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/home/widget/home_style.dart';
import 'package:intl/intl.dart';

import 'package:personal_financial_management/core/constants/function/extension.dart';
import 'package:personal_financial_management/features/main/home/widget/item_parent_widget.dart';
import 'package:personal_financial_management/features/main/home/widget/item_spending_widget.dart';
import 'package:personal_financial_management/features/main/home/widget/summary_spending.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin {
  late TabController _monthController;
  final List<DateTime> months = [];

  @override
  void initState() {
    super.initState();

    _monthController = TabController(length: 19, vsync: this);
    _monthController.index = 17;

    DateTime now = DateTime(DateTime.now().year, DateTime.now().month);

    months.add(DateTime(now.year, now.month + 1));
    months.add(now);

    for (int i = 1; i < 18; i++) {
      now = DateTime(now.year, now.month - 1);
      months.add(now);
    }

    _monthController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() { _monthController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Scaffold(backgroundColor: HomeStyle.background(context),
        body: Center(child: Text(AppLocalizations.of(context).translate('no_data'))));
    return Scaffold(
      backgroundColor: HomeStyle.background(context),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("spending")
              .where(
            "userId",
            isEqualTo: user.uid,
          )
              .orderBy("date", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text(
                AppLocalizations.of(context).translate('something_went_wrong'),
                style: TextStyle(color: HomeStyle.muted(context))));
            if (!snapshot.hasData) {
              return _loading();
            }

            // ===== ALL DATA (LŨY KẾ) =====
            final allSpendingList = snapshot.data!.docs
                .map((e) => Spending.fromFirebase(e))
                .toList();

            // ===== MONTH SELECTED =====
            final selectedMonth =
            months[18 - _monthController.index];

            // ===== FILTER BY MONTH =====
            final monthSpendingList = allSpendingList.where((e) {
              return e.dateTime.year == selectedMonth.year &&
                  e.dateTime.month == selectedMonth.month;
            }).toList();

            return _body(
              allSpendingList: allSpendingList,
              monthSpendingList: monthSpendingList,
            );
          },
        ),
      ),
    );
  }

  // ================= BODY =================

  Widget _body({
    required List<Spending> allSpendingList,
    required List<Spending> monthSpendingList,
  }) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: HomeStyle.decoration(context),
            height: 52,
            child: TabBar(
              controller: _monthController,
              isScrollable: true,
              splashBorderRadius: BorderRadius.circular(16),
              labelColor: HomeStyle.ink,
              unselectedLabelColor: HomeStyle.muted(context),
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(gradient: HomeStyle.gradient, borderRadius: BorderRadius.circular(16)),
              tabs: List.generate(19, (index) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width / 4,
                  child: Tab(
                    text: index == 17
                        ? AppLocalizations.of(context)
                        .translate('this_month')
                        .capitalize()
                        : (index == 18
                        ? AppLocalizations.of(context)
                        .translate('next_month')
                        .capitalize()
                        : (index == 16
                        ? AppLocalizations.of(context)
                        .translate('last_month')
                        .capitalize()
                        : DateFormat("MM/yyyy")
                        .format(months[18 - index]))),
                  ),
                );
              }),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: SummarySpending(
            monthSpendingList: monthSpendingList,
            allSpendingList: allSpendingList,
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              AppLocalizations.of(context)
                  .translate('spending_list'),
              textAlign: TextAlign.start,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeStyle.text(context)),
            ),
          ),
        ),

        monthSpendingList.isNotEmpty
            ? SliverToBoxAdapter(
          child: ItemParentIdWidget(
            spendingList: monthSpendingList, embedded: true,
          ),
        )
            : SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              AppLocalizations.of(context)
                  .translate('no_data'),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ================= LOADING =================

  Widget _loading() {
    return CustomScrollView(
      slivers: const [
        SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverToBoxAdapter(
          child: SummarySpending(
            monthSpendingList: [],
            allSpendingList: [], isLoading: true,
          ),
        ),
        SliverToBoxAdapter(child: ItemSpendingWidget(embedded: true)),
      ],
    );
  }
}
