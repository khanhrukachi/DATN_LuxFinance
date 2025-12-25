import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Widget tabBarChart({required TabController controller}) {
  const Color activeColor = Color(0xFF2DD8C6);

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              height: 52,
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
                splashBorderRadius: BorderRadius.circular(40),
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
                unselectedLabelColor:
                isDark ? Colors.white70 : Colors.black54,
                tabs: const [
                  Icon(FontAwesomeIcons.chartColumn, size: 20),
                  Icon(FontAwesomeIcons.chartPie, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
