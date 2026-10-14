import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/home/widget/home_style.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/features/main/home/widget/item_parent_widget.dart';
import 'package:personal_financial_management/features/main/home/widget/item_spending_widget.dart';
import 'package:personal_financial_management/features/main/home/widget/summary_spending.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/models/user.dart' as profile;
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedMonthIndex = 1;
  final List<DateTime> months = [];

  @override
  void initState() {
    super.initState();

    DateTime now = DateTime(DateTime.now().year, DateTime.now().month);

    months.add(DateTime(now.year, now.month + 1));
    months.add(now);

    for (int i = 1; i < 18; i++) {
      now = DateTime(now.year, now.month - 1);
      months.add(now);
    }

  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(backgroundColor: HomeStyle.background(context),
          body: Center(child: Text(AppLocalizations.of(context).translate('no_data'))));
    }
    return Scaffold(
      backgroundColor: HomeStyle.background(context),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('info')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)
                      .translate('something_went_wrong'),
                  style: TextStyle(color: HomeStyle.muted(context)),
                ),
              );
            }
            if (!profileSnapshot.hasData) return _loading();

            final profileData = profileSnapshot.data!;
            final appUser = profileData.exists
                ? profile.User.fromFirebase(profileData)
                : null;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('spending')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)
                          .translate('something_went_wrong'),
                      style: TextStyle(color: HomeStyle.muted(context)),
                    ),
                  );
                }
                if (!snapshot.hasData) return _loading();

                // All transactions are used for the selected-month list and
                // monthly income/expense totals. The balance comes from
                // appUser.money in the user's `info` document.
                final allSpendingList = snapshot.data!.docs
                    .map((e) => Spending.fromFirebase(e))
                    .toList();

                final selectedMonth = months[_selectedMonthIndex];
                final monthSpendingList = allSpendingList.where((e) {
                  return e.dateTime.year == selectedMonth.year &&
                      e.dateTime.month == selectedMonth.month;
                }).toList();

                return _body(
                  appUser: appUser,
                  allSpendingList: allSpendingList,
                  monthSpendingList: monthSpendingList,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ================= BODY =================

  Widget _body({
    required profile.User? appUser,
    required List<Spending> allSpendingList,
    required List<Spending> monthSpendingList,
  }) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        SliverToBoxAdapter(child: _monthSelector()),

        SliverToBoxAdapter(
          child: SummarySpending(
            monthSpendingList: monthSpendingList,
            allSpendingList: allSpendingList,
            user: appUser,
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

  void _changeMonth(int offset) {
    final next = _selectedMonthIndex + offset;
    if (next < 0 || next >= months.length) return;
    setState(() => _selectedMonthIndex = next);
  }

  Widget _monthSelector() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark
        ? const Color(0xFF2DD8C6)
        : const Color(0xFF14988F);
    final canGoBack = _selectedMonthIndex < months.length - 1;
    final canGoForward = _selectedMonthIndex > 0;

    Widget arrow({
      required IconData icon,
      required String tooltip,
      required bool enabled,
      required VoidCallback onPressed,
    }) => Material(
      color: const Color(0xFF2DD8C6).withOpacity(.13),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 42,
        height: 42,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: tooltip,
          onPressed: enabled ? onPressed : null,
          color: accent,
          disabledColor: HomeStyle.muted(context).withOpacity(.35),
          icon: Icon(icon, size: 24),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: HomeStyle.decoration(context),
      child: Row(
        children: [
          arrow(
            icon: Icons.chevron_left_rounded,
            tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
            enabled: canGoBack,
            onPressed: () => _changeMonth(1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                gradient: HomeStyle.gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                DateFormat('MM/yyyy').format(months[_selectedMonthIndex]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeStyle.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          arrow(
            icon: Icons.chevron_right_rounded,
            tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
            enabled: canGoForward,
            onPressed: () => _changeMonth(-1),
          ),
        ],
      ),
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
