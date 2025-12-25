import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class CustomTabBar extends StatelessWidget {
  const CustomTabBar({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final TabController controller;

  static const Color activeBlue = Color(0xFF2DD8C6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,

        /// ===== QUAN TRỌNG =====
        isScrollable: false, // chia đều 3 tab
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent, // ❌ XÓA DÒNG KẺ DƯỚI

        indicator: BoxDecoration(
          color: isDark ? Colors.white12 : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),

        labelColor: activeBlue,
        unselectedLabelColor:
        isDark ? Colors.white70 : Colors.black54,

        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),

        tabs: [
          _tab(context, 'week'),
          _tab(context, 'month'),
          _tab(context, 'year'),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String key) {
    return Center(
      child: Text(
        AppLocalizations.of(context).translate(key),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
