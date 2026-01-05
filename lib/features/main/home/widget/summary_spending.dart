import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class SummarySpending extends StatelessWidget {
  const SummarySpending({Key? key, this.spendingList}) : super(key: key);
  final List<Spending>? spendingList;

  int getTotalIncome(List<Spending> list) =>
      list.where((e) => e.money > 0).fold(0, (s, e) => s + e.money);

  int getTotalExpense(List<Spending> list) =>
      list.where((e) => e.money < 0).fold(0, (s, e) => s + e.money.abs());

  int getCurrentMoney(List<Spending> list) =>
      list.fold(0, (s, e) => s + e.money);


  @override
  Widget build(BuildContext context) {
    if (spendingList == null) return _loading(context);

    final income = getTotalIncome(spendingList!);
    final expense = getTotalExpense(spendingList!);
    final balance = getCurrentMoney(spendingList!);

    return _body(
      context,
      income: income,
      expense: expense,
      balance: balance,
    );
  }

  Widget _body(BuildContext context, {
    required int income,
    required int expense,
    required int balance,
  }) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final textSecondary =
    isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.blue.withOpacity(0.15)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.blue.withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Column(
          children: [
            _row(
              context,
              icon: Icons.arrow_downward_rounded,
              title: AppLocalizations.of(context)
                  .translate('total_amount_collected'),
              value: income,
              color: const Color(0xFF2FBF71),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 18),
            _row(
              context,
              icon: Icons.arrow_upward_rounded,
              title: AppLocalizations.of(context)
                  .translate('total_amount_spent'),
              value: expense,
              color: const Color(0xFFE5533D),
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 18),
            _row(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title:
              AppLocalizations.of(context).translate('current_money'),
              value: balance.abs(),
              color: balance >= 0
                  ? const Color(0xFF5B7CFA)
                  : const Color(0xFFE5533D),
              prefix: balance >= 0 ? "" : "-",
              isBold: true,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, {
    required IconData icon,
    required String title,
    required int value,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
    String prefix = "",
    bool isBold = false,
  }) {
    final format = NumberFormat.decimalPattern("vi");

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.30),
                color.withOpacity(0.08),
              ],
            ),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          "$prefix${format.format(value)} đ",
          style: TextStyle(
            fontSize: isBold ? 17 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _loading(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    // Màu nền card
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Màu shimmer: base và highlight
    final baseShimmer = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightShimmer = isDark ? Colors.grey.shade700 : Colors.grey
        .shade100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            _shimmerRow(baseShimmer, highlightShimmer),
            const SizedBox(height: 18),
            _shimmerRow(baseShimmer, highlightShimmer),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 18),
            _shimmerRow(baseShimmer, highlightShimmer, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _shimmerRow(Color baseShimmer, Color highlightShimmer,
      {bool isBold = false}) {
    return Row(
      children: [
        Shimmer.fromColors(
          baseColor: baseShimmer,
          highlightColor: highlightShimmer,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: baseShimmer,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 14,
            color: Colors.transparent,
          ),
        ),
        Shimmer.fromColors(
          baseColor: baseShimmer,
          highlightColor: highlightShimmer,
          child: Container(
            height: isBold ? 22 : 18,
            width: Random().nextInt(60) + 80,
            decoration: BoxDecoration(
              color: baseShimmer,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }
}
