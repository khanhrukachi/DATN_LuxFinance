import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    Key? key,
    required this.selectedType,
    required this.limitController,
    required this.onTypeTap,
  }) : super(key: key);
  final int? selectedType;
  final TextEditingController limitController;
  final VoidCallback onTypeTap;

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final valid =
        selectedType != null &&
        selectedType! >= 0 &&
        selectedType! < listType.length;
    final title = valid
        ? tr.translate(listType[selectedType!]['title']?.toString() ?? 'other')
        : tr.translate('select_category');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BudgetStyle.decoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: BudgetStyle.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  color: BudgetStyle.ink,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr.translate('budget_info'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: BudgetStyle.text(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: BudgetStyle.accent(context).withOpacity(.12),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: BudgetStyle.background(context),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: BudgetStyle.accent(context).withOpacity(.18),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: onTypeTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: BudgetStyle.accent(context).withOpacity(.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.category_outlined,
                          color: BudgetStyle.accent(context),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.translate('expense_type'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: BudgetStyle.muted(context),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: BudgetStyle.text(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: BudgetStyle.accent(context).withOpacity(.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: BudgetStyle.accent(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: limitController,
            keyboardType: TextInputType.number,
            cursorColor: BudgetStyle.accent(context),
            decoration: BudgetStyle.input(
              context,
              tr.translate('budget_limit'),
              icon: Icons.payments_outlined,
              hint: '2,000,000',
            ).copyWith(suffixText: '₫'),
          ),
        ],
      ),
    );
  }
}
