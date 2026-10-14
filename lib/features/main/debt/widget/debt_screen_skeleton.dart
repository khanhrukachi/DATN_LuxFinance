import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'package:shimmer/shimmer.dart';

Widget debtScreenSkeleton(BuildContext context) {
  final baseColor = DebtStyle.card(context);
  final highlightColor = DebtStyle.teal.withOpacity(.18);

  Widget placeholder({
    double? width,
    required double height,
    double radius = 14,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  return Shimmer.fromColors(
    baseColor: baseColor,
    highlightColor: highlightColor,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        placeholder(height: 82, radius: 20),
        const SizedBox(height: 14),
        placeholder(height: 142, radius: 24),
        const SizedBox(height: 18),
        placeholder(height: 50, radius: 16),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: placeholder(height: 38, radius: 20)),
            const SizedBox(width: 8),
            Expanded(child: placeholder(height: 38, radius: 20)),
            const SizedBox(width: 8),
            Expanded(child: placeholder(height: 38, radius: 20)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: placeholder(height: 36, radius: 20)),
            const SizedBox(width: 8),
            Expanded(child: placeholder(height: 36, radius: 20)),
            const SizedBox(width: 8),
            Expanded(child: placeholder(height: 36, radius: 20)),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          placeholder(height: 86, radius: 20),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}
