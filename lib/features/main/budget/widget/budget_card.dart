import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class BudgetCard extends StatelessWidget {
  final int? selectedType;
  final TextEditingController limitController;
  final VoidCallback onTypeTap;

  const BudgetCard({
    Key? key,
    required this.selectedType,
    required this.limitController,
    required this.onTypeTap,
  }) : super(key: key);

  String _getTitle(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return 'other';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).translate('budget_info'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onTypeTap,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).translate('expense_type'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedType == null
                          ? AppLocalizations.of(context).translate('select_category')
                          : AppLocalizations.of(context).translate(
                        _getTitle(listType[selectedType!]['title']),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: limitController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).translate('budget_limit'),
              hintText: "2,000,000đ",
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
