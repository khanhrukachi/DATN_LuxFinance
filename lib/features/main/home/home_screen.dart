import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/core/constants/function/extension.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("spending")
              .where(
            "userId",
            isEqualTo: FirebaseAuth.instance.currentUser!.uid,
          )
              .orderBy("date", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
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
        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: TabBar(
              controller: _monthController,
              isScrollable: true,
              labelColor: const Color.fromRGBO(0, 210, 255, 1),
              unselectedLabelColor:
              const Color.fromRGBO(45, 216, 198, 1),
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
              unselectedLabelStyle: AppStyles.p,
              indicatorColor: Colors.green,
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
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              AppLocalizations.of(context)
                  .translate('spending_list'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ),

        monthSpendingList.isNotEmpty
            ? SliverFillRemaining(
          child: ItemSpendingWidget(
            spendingList: monthSpendingList,
          ),
        )
            : SliverFillRemaining(
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
            allSpendingList: [],
          ),
        ),
        SliverFillRemaining(child: ItemSpendingWidget()),
      ],
    );
  }
}
