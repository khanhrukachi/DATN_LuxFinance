import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/main/home/view_list_spending_screen.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/spending.dart';

Widget showListSpendingPie({required List<Spending> list}) {
  final numberFormat = NumberFormat.currency(locale: "vi_VI");
  final int totalSum = list.isNotEmpty
      ? list.map((e) => e.money).reduce((value, element) => value + element)
      : 1;

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: listType.length,
    itemBuilder: (context, index) {
      if ([0, 10, 21, 27, 35, 38].contains(index)) return const SizedBox.shrink();

      final List<Spending> spendingList =
      list.where((element) => element.type == index).toList();

      if (spendingList.isEmpty) return const SizedBox.shrink();

      final int sumSpending =
      spendingList.map((e) => e.money).reduce((value, element) => value + element);
      final double percent = sumSpending / totalSum;

      final Map<String, dynamic> typeItem = listType[index];
      final String titleKey = typeItem["title"] ?? "other";
      final String? imagePath = typeItem["image"];
      final Color baseColor = typeItem["color"] ?? Colors.red;
      final bool isOver = percent >= 1.0;
      final Color mainColor = isOver ? Colors.green : baseColor;

      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      final Color surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
      final Color textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1C);
      final Color textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              createRoute(
                screen: ViewListSpendingPage(spendingList: spendingList),
                begin: const Offset(1, 0),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: mainColor.withOpacity(isDark ? 0.25 : 0.12)),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: mainColor.withOpacity(0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        mainColor.withOpacity(0.3),
                        mainColor.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: imagePath != null
                      ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(imagePath),
                  )
                      : Icon(Icons.category, color: mainColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).translate(titleKey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary),
                            ),
                          ),
                          Text(
                            "${(percent * 100).toStringAsFixed(2)}%",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percent.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor:
                          isDark ? Colors.white12 : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${_formatCurrency(sumSpending)} VND",
                        style: TextStyle(
                          fontSize: 13,
                          color: isOver ? mainColor : textSecondary,
                          fontWeight: isOver ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right,
                  color: mainColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _formatCurrency(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
  );
}
