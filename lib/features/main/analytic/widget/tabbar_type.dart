import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class TabBarType extends StatelessWidget {
  const TabBarType({Key? key, required this.controller}) : super(key: key);
  final TabController controller;

  static const Color activeColor = Color(0xFF2DD8C6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            height: 48,
            width: 260,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFF2F3F7),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: activeColor.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: TabBar(
              controller: controller,
              dividerColor: Colors.transparent,
              overlayColor:
              MaterialStateProperty.all(Colors.transparent),

              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),

              indicator: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),

              labelColor: Colors.white,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),

              unselectedLabelColor:
              isDark ? Colors.white70 : Colors.black54,
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),

              tabs: [
                Tab(
                  text: AppLocalizations.of(context)
                      .translate('spending'),
                ),
                Tab(
                  text: AppLocalizations.of(context)
                      .translate('income'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
