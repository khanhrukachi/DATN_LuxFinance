import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class TotalReport extends StatelessWidget {
  const TotalReport({Key? key, required this.list}) : super(key: key);
  final List<Spending> list;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numberFormat = NumberFormat.currency(locale: "vi_VI");

    final spending = list
        .where((e) => e.money < 0)
        .fold<int>(0, (sum, e) => sum + e.money);

    final income = list
        .where((e) => e.money > 0)
        .fold<int>(0, (sum, e) => sum + e.money);

    final revenue = income + spending;

    return Card(
      elevation: isDark ? 0 : 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _reportItem(
                  context,
                  title: AppLocalizations.of(context).translate('income'),
                  amount: income,
                  color: Colors.green,
                  icon: Icons.arrow_downward_rounded,
                  numberFormat: numberFormat,
                ),
                const SizedBox(width: 12),
                _reportItem(
                  context,
                  title: AppLocalizations.of(context).translate('spending'),
                  amount: spending,
                  color: Colors.red,
                  icon: Icons.arrow_upward_rounded,
                  numberFormat: numberFormat,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _reportItem(
              context,
              title: AppLocalizations.of(context)
                  .translate('revenue_expenditure'),
              amount: revenue,
              color: revenue >= 0 ? Colors.blue : Colors.orange,
              icon: Icons.account_balance_wallet_rounded,
              numberFormat: numberFormat,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportItem(
      BuildContext context, {
        required String title,
        required int amount,
        required Color color,
        required IconData icon,
        required NumberFormat numberFormat,
        bool fullWidth = false,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? Colors.white10 : color.withOpacity(0.08),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            numberFormat.format(amount),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );

    return fullWidth ? content : Expanded(child: content);
  }
}
