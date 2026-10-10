import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
Widget circleText({required String text, required Color color}) => Container(
  width: 36, height: 36,
  decoration: BoxDecoration(gradient: SpendingStyle.gradient, borderRadius: BorderRadius.circular(12)),
  alignment: Alignment.center,
  child: Text(text.toUpperCase(), maxLines: 1,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SpendingStyle.ink)),
);
