import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
Widget boxText({required String text, required int number, Color? color}) => Builder(
  builder: (context) => Container(width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AnalyticStyle.background(context),
          borderRadius: BorderRadius.circular(14), border: Border.all(color: AnalyticStyle.teal.withOpacity(.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: TextStyle(fontSize: 12, color: AnalyticStyle.muted(context))),
        const SizedBox(height: 5),
        Text(AnalyticStyle.money(context, number), style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w700, color: color ?? AnalyticStyle.text(context))),
      ])),
);
