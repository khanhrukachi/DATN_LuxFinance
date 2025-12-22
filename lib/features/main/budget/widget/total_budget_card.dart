import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class TotalBudgetCard extends StatelessWidget {
  final double spent;
  final double limit;
  final double progress;

  const TotalBudgetCard({
    Key? key,
    required this.spent,
    required this.limit,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            // HEADER
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
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr.translate("budget_this_month"), // localization
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // LIMIT + %
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${_formatCurrency(limit.toInt())} đ", // đổi sang "đ"
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

            // SPENT
            Text(
              "${tr.translate("spent")}: ${_formatCurrency(spent.toInt())} đ", // đổi sang "đ"
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),

            const SizedBox(height: 18),

            // PROGRESS
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

            // REMAIN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr.translate("remaining"),
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
                Text(
                  "${_formatCurrency((limit - spent).toInt())} đ", // đổi sang "đ"
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

  String _formatCurrency(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
    );
  }
}
