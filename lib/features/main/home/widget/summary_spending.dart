import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/features/main/home/widget/home_style.dart';

class SummarySpending extends StatelessWidget {
  const SummarySpending({
    Key? key,
    required this.monthSpendingList,
    required this.allSpendingList,
    this.isLoading = false,
  }) : super(key: key);

  final List<Spending> monthSpendingList;
  final List<Spending> allSpendingList;
  final bool isLoading;

  int getTotalIncome(List<Spending> list) =>
      list.where((e) => e.money > 0).fold(0, (sum, e) => sum + e.money);
  int getTotalExpense(List<Spending> list) =>
      list.where((e) => e.money < 0).fold(0, (sum, e) => sum + e.money.abs());
  int getBalance(List<Spending> list) =>
      list.fold(0, (sum, e) => sum + e.money);

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final balance = getBalance(allSpendingList);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: HomeStyle.decoration(context, hero: true),
      child: isLoading
          ? _loading(context)
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                decoration: BoxDecoration(
                  color: HomeStyle.card(context).withOpacity(.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: HomeStyle.accent(context).withOpacity(.12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.translate('current_money'),
                            style: TextStyle(
                              fontSize: 12,
                              color: HomeStyle.muted(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _amount(
                            context,
                            balance,
                            fontSize: 25,
                            color: balance < 0
                                ? HomeStyle.danger
                                : HomeStyle.text(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: HomeStyle.gradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: HomeStyle.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final income = _metric(context,
                title: tr.translate('income'),
                amount: getTotalIncome(monthSpendingList),
                icon: Icons.south_west_rounded,
                color: HomeStyle.accent(context));
            final expense = _metric(context,
                title: tr.translate('spending'),
                amount: getTotalExpense(monthSpendingList),
                icon: Icons.north_east_rounded,
                color: HomeStyle.danger);
            if (constraints.maxWidth < 240 ||
                MediaQuery.of(context).textScaleFactor > 1.4) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [income, const SizedBox(height: 8), expense]);
            }
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: income),
                    const SizedBox(width: 10), Expanded(child: expense)]),
            );
          }),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, {
    required String title, required int amount,
    required IconData icon, required Color color,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: HomeStyle.card(context).withOpacity(.65),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(.12)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Expanded(child: Text(title, style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w500, color: HomeStyle.muted(context)))),
      ]),
      const SizedBox(height: 5),
      _amount(context, amount, fontSize: 16, color: color),
    ]),
  );

  Widget _amount(BuildContext context, int amount, {
    required double fontSize, required Color color,
  }) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(HomeStyle.money(context, amount), maxLines: 1,
          style: TextStyle(fontSize: fontSize,
              fontWeight: FontWeight.w700, color: color)),
    ),
  );

  Widget _loading(BuildContext context) => Shimmer.fromColors(
    baseColor: HomeStyle.card(context),
    highlightColor: HomeStyle.teal.withOpacity(.18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 100, height: 12, color: Colors.white),
      const SizedBox(height: 7),
      Container(width: 180, height: 28, color: Colors.white),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Container(height: 62, decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)))),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 62, decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)))),
      ]),
    ]),
  );
}
