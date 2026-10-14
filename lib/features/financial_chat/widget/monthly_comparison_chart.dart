import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'monthly_comparison_bar.dart';

class MonthlyComparisonChart extends StatelessWidget {
  const MonthlyComparisonChart({
    super.key,
    required this.evidence,
  });

  final Map<String, dynamic> evidence;

  double _amount(Map period) {
    final value =
        period['amount'] ?? period['expense'] ?? period['income'];

    if (value is! num) return 0;
    final result = value.toDouble();
    return result.isFinite ? result : 0;
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
          MonthlyComparisonBar(
            label:
                '${(evidence['previous'] as Map)['startDate'] ?? ''} → ${(evidence['previous'] as Map)['endDate'] ?? ''}',
            amount: previous,
            maximum: maximum,
            color: const Color(0xFF00A8CC),
          ),
          MonthlyComparisonBar(
            label:
                '${(evidence['current'] as Map)['startDate'] ?? ''} → ${(evidence['current'] as Map)['endDate'] ?? ''}',
            amount: current,
            maximum: maximum,
            color: const Color(0xFF2DD8C6),
          ),
        ],
      ),
    );
  }
}
