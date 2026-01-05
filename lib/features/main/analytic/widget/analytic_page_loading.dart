import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AnalyticPageLoading extends StatelessWidget {
  final bool isPieChart;
  final int itemCount;

  const AnalyticPageLoading({
    Key? key,
    this.isPieChart = false,
    this.itemCount = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final baseColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade600 : Colors.grey.shade100;

    Widget shimmerBox({double? w, double? h, double radius = 8}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 200,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 100,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: List.generate(itemCount, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Icon shimmer
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: baseColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Text shimmer
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              shimmerBox(w: 120, h: 16),
                              const SizedBox(height: 10),
                              shimmerBox(w: double.infinity, h: 12),
                              const SizedBox(height: 8),
                              shimmerBox(w: 100, h: 12),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Icon end shimmer
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: baseColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
