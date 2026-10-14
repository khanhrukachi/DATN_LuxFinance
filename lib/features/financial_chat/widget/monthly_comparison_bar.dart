import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthlyComparisonBar extends StatelessWidget {
  const MonthlyComparisonBar({
    super.key,
    required this.label,
    required this.amount,
    required this.maximum,
    required this.color,
  });

  final String label;
  final double amount;
  final double maximum;
  final Color color;

  String _money(BuildContext context, double value) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final locale = languageCode == 'vi' ? 'vi_VN' : 'en_US';
    return NumberFormat.currency(
      locale: locale,
      symbol: '₫',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
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
                _money(context, amount),
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
                      color: textColor.withOpacity(.08),
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
}
