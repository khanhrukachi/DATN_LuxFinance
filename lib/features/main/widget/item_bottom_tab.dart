import 'package:flutter/material.dart';

Widget itemBottomTab({
  required String text,
  required int index,
  required int current,
  required IconData icon,
  IconData? activeIcon,
  double iconSize = 24,
  double textSize = 10, // 👈 CHỈNH SIZE CHỮ
  required VoidCallback action,
}) {
  final bool isActive = index == current;

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: action,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isActive && activeIcon != null ? activeIcon : icon,
          size: iconSize,
          color: isActive
              ? Colors.blue
              : Colors.grey,
        ),
        const SizedBox(height: 4),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: textSize, // 👈 SIZE CHỮ Ở ĐÂY
            fontWeight: FontWeight.w500,
            color: isActive
                ? Colors.blue
                : Colors.grey,
          ),
        ),
      ],
    ),
  );
}
