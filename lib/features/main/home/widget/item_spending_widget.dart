import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/features/main/home/view_list_spending_screen.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ItemSpendingWidget extends StatelessWidget {
  const ItemSpendingWidget({Key? key, this.spendingList}) : super(key: key);
  final List<Spending>? spendingList;

  @override
  Widget build(BuildContext context) {
    return spendingList != null
        ? ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: listType.length,
      itemBuilder: (context, index) {
        if ([0, 10, 21, 27, 35, 38].contains(index)) {
          return const SizedBox.shrink();
        }

        final list =
        spendingList!.where((e) => e.type == index).toList();
        if (list.isEmpty) return const SizedBox.shrink();

        return _item(context, index, list);
      },
    )
        : _loading(context);
  }

  // ================= ITEM =================

  Widget _item(BuildContext context, int index, List<Spending> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numberFormat = NumberFormat.decimalPattern("vi");

    final Map<String, dynamic> typeItem =
    listType[index] as Map<String, dynamic>;

    final String titleKey = typeItem['title'] as String;
    final String? imagePath = typeItem['image'] as String?;
    final Color baseColor =
        typeItem['color'] as Color? ?? const Color(0xFF5B7CFA);

    final int totalMoney =
    list.map((e) => e.money).reduce((a, b) => a + b);
    final bool isExpense = totalMoney < 0;

    final Color surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final Color textPrimary =
    isDark ? Colors.white : const Color(0xFF1C1C1C);

    final Color accent = isExpense
        ? const Color(0xFFE5533D)
        : const Color(0xFF2FBF71);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).push(
            createRoute(
              screen: ViewListSpendingPage(spendingList: list),
              begin: const Offset(1, 0),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: accent.withOpacity(isDark ? 0.25 : 0.12),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: accent.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      baseColor.withOpacity(0.30),
                      baseColor.withOpacity(0.08),
                    ],
                  ),
                ),
                child: imagePath != null
                    ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(imagePath),
                )
                    : Icon(Icons.category, color: baseColor),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate(titleKey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),

              // MONEY
              Text(
                "${isExpense ? "-" : "+"}${numberFormat.format(totalMoney.abs())} đ",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final baseShimmer = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightShimmer = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: 5,
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Shimmer.fromColors(
                  baseColor: baseShimmer,
                  highlightColor: highlightShimmer,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: baseShimmer,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: textLoading(Random().nextInt(80) + 80,
                      baseShimmer: baseShimmer, highlightShimmer: highlightShimmer),
                ),
                const SizedBox(width: 16),
                textLoading(Random().nextInt(50) + 60,
                    baseShimmer: baseShimmer, highlightShimmer: highlightShimmer),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget textLoading(int width,
      {int height = 16, required Color baseShimmer, required Color highlightShimmer}) {
    return Shimmer.fromColors(
      baseColor: baseShimmer,
      highlightColor: highlightShimmer,
      child: Container(
        height: height.toDouble(),
        width: width.toDouble(),
        decoration: BoxDecoration(
          color: baseShimmer,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

Widget textLoading(int width, {int height = 16}) {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      height: height.toDouble(),
      width: width.toDouble(),
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}
