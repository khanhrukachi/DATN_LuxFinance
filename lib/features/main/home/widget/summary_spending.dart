import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:personal_financial_management/models/spending.dart';

class SummarySpending extends StatefulWidget {
  const SummarySpending({Key? key, this.spendingList}) : super(key: key);
  final List<Spending>? spendingList;

  @override
  State<SummarySpending> createState() => _SummarySpendingState();
}

class _SummarySpendingState extends State<SummarySpending> {
  final numberFormat = NumberFormat.currency(locale: "vi_VI");

  // ================== CALC ==================

  int getTotalIncome(List<Spending> list) {
    return list
        .where((e) => e.money > 0)
        .fold(0, (sum, e) => sum + e.money);
  }

  int getTotalExpense(List<Spending> list) {
    return list
        .where((e) => e.money < 0)
        .fold(0, (sum, e) => sum + e.money.abs());
  }

  int getCurrentMoney(List<Spending> list) {
    return list.fold(0, (sum, e) => sum + e.money);
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    if (widget.spendingList == null) return loadingSummary();

    final totalIncome = getTotalIncome(widget.spendingList!);
    final totalExpense = getTotalExpense(widget.spendingList!);
    final currentMoney = getCurrentMoney(widget.spendingList!);

    return body(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      currentMoney: currentMoney,
    );
  }

  Widget body({
    required int totalIncome,
    required int totalExpense,
    required int currentMoney,
  }) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              summaryRow(
                title: "Tổng tiền đã thu",
                value: totalIncome,
                color: Colors.green,
                prefix: "+",
              ),
              const SizedBox(height: 15),
              summaryRow(
                title: "Tổng tiền đã chi",
                value: totalExpense,
                color: Colors.red,
                prefix: "-",
              ),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 15),
              summaryRow(
                title: "Số tiền hiện tại",
                value: currentMoney.abs(),
                color: currentMoney >= 0 ? Colors.blue : Colors.red,
                prefix: currentMoney >= 0 ? "" : "-",
                isBold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget summaryRow({
    required String title,
    required int value,
    required Color color,
    String prefix = "",
    bool isBold = false,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          "$prefix${numberFormat.format(value)}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  // ================== LOADING ==================

  Widget loadingSummary() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              shimmerRow(),
              const SizedBox(height: 15),
              shimmerRow(),
              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 15),
              shimmerRow(isBold: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget shimmerRow({bool isBold = false}) {
    return Row(
      children: [
        Container(
          height: 20,
          width: 120,
          color: Colors.transparent,
        ),
        const Spacer(),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: isBold ? 28 : 25,
            width: Random().nextInt(50) + 100,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      ],
    );
  }
}

