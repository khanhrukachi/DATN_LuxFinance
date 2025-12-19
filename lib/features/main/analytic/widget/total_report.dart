import 'package:flutter/material.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class TotalReport extends StatelessWidget {
  const TotalReport({Key? key, required this.list}) : super(key: key);
  final List<Spending> list;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<Spending> spendingList =
    list.where((element) => element.money < 0).toList();

    int spending = spendingList.isEmpty
        ? 0
        : spendingList
        .map((e) => e.money)
        .reduce((value, element) => value + element);

    List<Spending> incomeList = list.where((element) => element.money > 0).toList();

    int income = incomeList.isEmpty
        ? 0
        : incomeList
        .map((e) => e.money)
        .reduce((value, element) => value + element);

    int revenue = income + spending;

    final bgColor = isDark ? Colors.grey.shade900 : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: bgColor,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _buildBox(
                  context,
                  title: AppLocalizations.of(context).translate('income'),
                  amount: income,
                  color: Colors.blue,
                  icon: Icons.arrow_downward,
                  textColor: textColor,
                ),
                _buildBox(
                  context,
                  title: AppLocalizations.of(context).translate('spending'),
                  amount: spending,
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                  textColor: textColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBox(
              context,
              title: AppLocalizations.of(context).translate('revenue_expenditure'),
              amount: revenue,
              color: revenue >= 0 ? Colors.green : Colors.orange,
              icon: Icons.attach_money,
              isExpanded: false,
              textColor: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBox(BuildContext context,
      {required String title,
        required int amount,
        required Color color,
        required IconData icon,
        bool isExpanded = true,
        required Color textColor}) {
    Widget box = Container(
      padding: const EdgeInsets.all(5),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "$amount",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (isExpanded) {
      return Expanded(child: box);
    } else {
      return box;
    }
  }
}
