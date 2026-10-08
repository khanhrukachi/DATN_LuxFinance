import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
// Thêm import AppLocalizations giống financial_chat_screen.dart.

class MonthlyComparisonChart extends StatelessWidget {
  const MonthlyComparisonChart({
    super.key,
    required this.evidence,
  });

  final Map<String, dynamic> evidence;

  double _amount(Map period) {
    final value =
        period['amount'] ?? period['income'] ?? period['expense'];

    if (value is! num) return 0;
    final result = value.toDouble();
    return result.isFinite ? result : 0;
  }

  String _money(double value) {
    final digits = value.abs().round().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
    );
    return '${value < 0 ? '-' : ''}$formatted ₫';
  }

  @override
  Widget build(BuildContext context) {
    final current = _amount(evidence['current'] as Map);
    final previous = _amount(evidence['previous'] as Map);
    final maximum = current.abs() > previous.abs()
        ? current.abs()
        : previous.abs();

    final textColor = Theme.of(context).colorScheme.onSurface;
    final localizations = AppLocalizations.of(context);

    Widget bar(String label, double amount, Color color) {
      final fraction = maximum == 0 ? 0.0 : amount.abs() / maximum;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(label, style: TextStyle(color: textColor)),
                Text(
                  _money(amount),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 18,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: textColor.withValues(alpha: 0.08),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction,
                        heightFactor: 1,
                        child: ColoredBox(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2DD8C6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.translate('chat_comparison_chart'),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          bar(
            localizations.translate('chat_previous_month'),
            previous,
            const Color(0xFF00A8CC),
          ),
          bar(
            localizations.translate('chat_current_month'),
            current,
            const Color(0xFF2DD8C6),
          ),
        ],
      ),
    );
  }
}