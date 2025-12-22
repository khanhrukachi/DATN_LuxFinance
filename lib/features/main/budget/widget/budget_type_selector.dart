import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class BudgetTypeSelector extends StatelessWidget {
  final int? selectedType;

  const BudgetTypeSelector({Key? key, this.selectedType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final expenseList = listType.where((item) {
      final title = item['title'] ?? '';
      final image = item['image'];
      const nonExpenseTitles = [
        'salary','other_income','money_transferred','money_transferred_to',
        'invest','debt_collection','borrow','loan','pay','pay_interest',
        'earn_profit','new_group','current_money'
      ];
      return !nonExpenseTitles.contains(title) && image != null;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // HANDLE
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('select_category'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: expenseList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = expenseList[index];
                final titleKey = item['title'] ?? 'other';
                final image = item['image']!;
                final color = Colors.blue;
                final isSelected = selectedType != null &&
                    listType[selectedType!]['title'] == titleKey;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(image),
                    ),
                  ),
                  title: Text(AppLocalizations.of(context).translate(titleKey)),
                  trailing: isSelected ? Icon(Icons.check, color: color) : null,
                  onTap: () {
                    final originalIndex = listType.indexWhere(
                            (element) => element['title'] == titleKey);
                    Navigator.pop(context, originalIndex);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
