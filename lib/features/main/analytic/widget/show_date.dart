import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/function/get_date.dart';

Widget showDate({
  required String date,
  required int index,
  required DateTime now,
  required Function(String, DateTime) action,
}) {
  const Color activeBlue = Color(0xFF2DD8C6);

  return Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final Color textColor = isDark
          ? Colors.white
          : activeBlue;

      return SizedBox(
        width: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              splashRadius: 20,
              onPressed: () {
                DateTime newDate;
                if (index == 0) {
                  newDate = now.subtract(const Duration(days: 7));
                  action(getWeek(newDate), newDate);
                } else if (index == 1) {
                  newDate = DateTime(now.year, now.month - 1);
                  action(getMonth(newDate), newDate);
                } else {
                  newDate = DateTime(now.year - 1, now.month);
                  action(getYear(newDate), newDate);
                }
              },
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: textColor,
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            IconButton(
              splashRadius: 20,
              onPressed: () {
                DateTime newDate;
                if (index == 0) {
                  newDate = now.add(const Duration(days: 7));
                  action(getWeek(newDate), newDate);
                } else if (index == 1) {
                  newDate = DateTime(now.year, now.month + 1);
                  action(getMonth(newDate), newDate);
                } else {
                  newDate = DateTime(now.year + 1, now.month);
                  action(getYear(newDate), newDate);
                }
              },
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    },
  );
}
