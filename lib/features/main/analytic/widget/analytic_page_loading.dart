import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';

class AnalyticPageLoading extends StatelessWidget {
  const AnalyticPageLoading({Key? key, this.isPieChart = false, this.itemCount = 5}) : super(key: key);
  final bool isPieChart;
  final int itemCount;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    child: Shimmer.fromColors(baseColor: AnalyticStyle.card(context),
        highlightColor: AnalyticStyle.teal.withOpacity(.16),
        child: Column(children: [
          Container(height: 300, decoration: AnalyticStyle.decoration(context)),
          const SizedBox(height: 16),
          Container(height: 146, decoration: AnalyticStyle.decoration(context)),
          const SizedBox(height: 16),
          for (var i = 0; i < itemCount; i++) Padding(padding: const EdgeInsets.only(bottom: 10),
              child: Container(height: 86, decoration: AnalyticStyle.decoration(context))),
        ])),
  );
}
