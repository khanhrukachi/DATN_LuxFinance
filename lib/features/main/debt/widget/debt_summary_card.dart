import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'debt_helpers.dart';

class DebtSummaryCard extends StatelessWidget {
  final int toCollect;
  final int toPay;
  final int overdueCount;
  final int completedCount;

  const DebtSummaryCard({
    super.key,
    required this.toCollect,
    required this.toPay,
    required this.overdueCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final dark = SpendingStyle.dark(context);
    final collectColor = dark
        ? const Color(0xFF62DCA5)
        : const Color(0xFF168353);
    final payColor = dark ? const Color(0xFFFFAB72) : const Color(0xFFC75D22);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SpendingStyle.decoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 21,
                color: SpendingStyle.accent(context),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  debtTranslate(context, 'debt_total'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SpendingStyle.text(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _amount(
            context,
            'debt_to_collect',
            toCollect,
            collectColor,
            Icons.call_received_rounded,
          ),
          const SizedBox(height: 10),
          _amount(
            context,
            'debt_to_pay',
            toPay,
            payColor,
            Icons.call_made_rounded,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _status(
                context,
                Icons.schedule_rounded,
                overdueCount,
                'debt_overdue_count',
                overdueCount > 0 ? payColor : SpendingStyle.muted(context),
              ),
              _status(
                context,
                Icons.check_circle_outline_rounded,
                completedCount,
                'debt_completed_count',
                collectColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amount(
    BuildContext context,
    String label,
    int amount,
    Color color,
    IconData icon,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(.09),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(.24)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Text(
            debtTranslate(context, label),
            maxLines: 2,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              debtMoney(amount),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _status(
    BuildContext context,
    IconData icon,
    int count,
    String label,
    Color color,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withOpacity(.07),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$count ${debtTranslate(context, label)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}
