import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/analytic/widget/analytic_style.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
class TabBarType extends StatelessWidget {
  const TabBarType({Key? key, required this.controller}) : super(key: key);
  final TabController controller;
  static const Color activeColor = AnalyticStyle.teal;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: AnalyticTabs(controller: controller,
        tabs: [Tab(text: AppLocalizations.of(context).translate('spending')),
          Tab(text: AppLocalizations.of(context).translate('income'))]),
  );
}
