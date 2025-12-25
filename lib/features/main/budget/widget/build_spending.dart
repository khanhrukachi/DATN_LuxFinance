import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/view_spending/view_spending_page.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:shimmer/shimmer.dart';

class BuildSpending extends StatelessWidget {
  const BuildSpending({
    Key? key,
    this.spendingList,
    this.date,
    this.change,
  }) : super(key: key);

  final List<Spending>? spendingList;
  final DateTime? date;
  final Function(Spending spending)? change;

  @override
  Widget build(BuildContext context) {
    if (spendingList == null) {
      return loadingItemSpending();
    }

    if (spendingList!.isEmpty) {
      return Center(
        child: Text(
          "${AppLocalizations.of(context).translate('you_have_spending_the_day')} "
              "${DateFormat("dd/MM/yyyy").format(date!)}",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF5350), // ✅ FIX withOpacity
          ),
        ),
      );
    }

    return showListSpending(context, spendingList!);
  }

  // ================= LIST SPENDING =================
  Widget showListSpending(BuildContext context, List<Spending> spendingList) {
    final numberFormat = NumberFormat.currency(locale: "vi_VI");

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: spendingList.length,
      itemBuilder: (context, index) {
        final spending = spendingList[index];

        final typeData =
        listType[spending.type] as Map<String, dynamic>;

        final String imagePath = typeData["image"] as String;
        final String titleKey = typeData["title"] as String;

        return InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.of(context).push(
              createRoute(
                screen: ViewSpendingPage(
                  spending: spending,
                  change: (value) {
                    if (change != null) change!(value);
                  },
                ),
                begin: const Offset(1, 0),
              ),
            );
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 10,
              ),
              child: Row(
                children: [
                  Image.asset(
                    imagePath,
                    width: 40,
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: Text(
                      spending.type == 41
                          ? (spending.typeName ?? "")
                          : AppLocalizations.of(context)
                          .translate(titleKey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      numberFormat.format(spending.money),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_ios_outlined, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= LOADING =================
  Widget loadingItemSpending() {
    final random = Random();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: 6,
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 14,
                      width: random.nextInt(80) + 80,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: 14,
                    width: random.nextInt(40) + 60,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
