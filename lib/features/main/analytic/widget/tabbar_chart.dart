import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
Widget tabBarChart({required TabController controller}) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
  child: AnalyticTabs(controller: controller, width: 200,
      tabs: const [Tab(icon: Icon(Icons.bar_chart_rounded, size: 22)),
        Tab(icon: Icon(Icons.donut_large_rounded, size: 21))]),
);
