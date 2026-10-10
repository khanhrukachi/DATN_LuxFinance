import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
class CustomTabBar extends StatelessWidget {
  const CustomTabBar({Key? key, required this.controller}) : super(key: key);
  final TabController controller;
  static const Color activeBlue = AnalyticStyle.teal;
  @override
  Widget build(BuildContext context) => AnalyticTabs(controller: controller,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    tabs: [for (final key in ['week', 'month', 'year'])
      Tab(child: Text(AppLocalizations.of(context).translate(key), maxLines: 1, overflow: TextOverflow.ellipsis))],
  );
}
