import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class TotalBudgetCard extends StatelessWidget {
  final double spent;
  final double limit;
  final double progress;
  final bool isLoading;

  const TotalBudgetCard({
    Key? key,
    required this.spent,
    required this.limit,
    required this.progress,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isLoading ? _loading(context) : _buildCard(context);
  }

  Widget _buildCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOver = progress >= 1.0;
    final percent = (progress * 100).clamp(0, 999);
    final accent = isOver ? const Color(0xFFE5533D) : const Color(0xFF5B7CFA);
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final tr = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withOpacity(isDark ? 0.25 : 0.15)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: accent.withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accent.withOpacity(0.30),
                        accent.withOpacity(0.08),
                      ],
                    ),
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded, color: accent),
                ),
                const SizedBox(width: 12),
                Text(
                  tr.translate("budget_this_month"),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_formatCurrency(limit.toInt())} đ",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  "${percent.toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "${tr.translate("spent")}: ${_formatCurrency(spent.toInt())} đ",
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr.translate("remaining"),
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                Text(
                  "${_formatCurrency((limit - spent).toInt())} đ",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isOver ? const Color(0xFFE5533D) : const Color(0xFF2FBF71),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER: ICON + TITLE
            Row(
              children: [
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: shimmerBox(w: 140, h: 16, radius: 6),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: shimmerBox(w: 160, h: 28, radius: 6),
                ),
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: shimmerBox(w: 40, h: 14, radius: 6),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: shimmerBox(w: 120, h: 12, radius: 6),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: shimmerBox(w: double.infinity, h: 12, radius: 10),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: shimmerBox(w: 70, h: 12, radius: 6),
                ),
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: shimmerBox(w: 90, h: 14, radius: 6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  String _formatCurrency(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
    );
  }
}
