import 'package:personal_financial_management/features/main/widget/main_style.dart';
import 'package:flutter/material.dart';

Widget itemBottomTab({required String text, required int index, required int current,
  required IconData icon, IconData? activeIcon, double iconSize = 24,
  double textSize = 10, required VoidCallback action}) => Builder(builder: (context) {
  final active = index == current;
  final color = active ? MainStyle.accent(context) : MainStyle.muted(context);
  return Semantics(selected: active, button: true,
      child: Material(color: active ? MainStyle.accent(context).withOpacity(.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: action,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(active && activeIcon != null ? activeIcon : icon, size: iconSize, color: color),
                  const SizedBox(height: 5),
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: textSize, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color)),
                ]))),
      ));
});
