import 'package:personal_financial_management/features/main/widget/main_style.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class CustomTabBar extends StatelessWidget {
  const CustomTabBar({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(12),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360),
        child: Material(color: MainStyle.card(context), clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: MainStyle.teal.withOpacity(.16))),
            child: Padding(padding: const EdgeInsets.all(4),
                child: TabBar(dividerColor: Colors.transparent, indicatorSize: TabBarIndicatorSize.tab,
                    splashBorderRadius: BorderRadius.circular(14),
                    labelColor: MainStyle.ink, unselectedLabelColor: MainStyle.muted(context),
                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    indicator: BoxDecoration(gradient: MainStyle.gradient, borderRadius: BorderRadius.circular(14)),
                    tabs: [
                      Tab(height: 44, text: AppLocalizations.of(context).translate('spending')),
                      Tab(height: 44, text: AppLocalizations.of(context).translate('incomes')),
                    ])))),
  );
}
