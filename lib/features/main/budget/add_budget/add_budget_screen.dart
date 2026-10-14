import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';

import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_card.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_type_selector.dart';
import 'package:personal_financial_management/models/budget.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class AddBudgetPage extends StatefulWidget {
  const AddBudgetPage({super.key});

  @override
  State<AddBudgetPage> createState() => _AddBudgetPageState();
}

class _AddBudgetPageState extends State<AddBudgetPage> {
  int? selectedType;
  final TextEditingController _limitController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  // ===================== SAVE =====================
  Future<void> _saveBudget() async {
    if (isLoading) return;

    if (selectedType == null) {
      _showSnack('please_select_budget_type');
      return;
    }

    if (_limitController.text.isEmpty) {
      _showSnack('please_enter_budget_limit');
      return;
    }

    final limit =
        int.tryParse(_limitController.text.replaceAll(RegExp(r'[.,\s]'), '')) ??
            0;

    if (limit <= 0) {
      _showSnack('budget_limit_must_be_greater_than_zero');
      return;
    }

    setState(() => isLoading = true);

    try {
      final month = DateTime.now().month;
      final year = DateTime.now().year;

      // 🔍 check trùng budget
      final existingBudgets = await SpendingFirebase.getBudgetsOfMonth(
        month,
        year,
      );
      if (!mounted) return;

      Budget? conflictingBudget;
      for (final budget in existingBudgets) {
        if (budget.type != selectedType &&
            budgetTypesOverlap(budget.type, selectedType!)) {
          conflictingBudget = budget;
          break;
        }
      }

      if (conflictingBudget != null) {
        _showOverlapSnack();
        return;
      }

      Budget? existedBudget;
      for (final b in existingBudgets) {
        if (b.type == selectedType) {
          existedBudget = b;
          break;
        }
      }

      final budget = Budget(
        id: existedBudget?.id,
        type: selectedType!,
        month: month,
        year: year,
        limitMoney: limit,
      );

      await SpendingFirebase.addOrUpdateBudget(budget);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      _showSnack('something_went_wrong');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ===================== TYPE =====================
  void _openTypeSelector() async {
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetTypeSelector(selectedType: selectedType),
    );

    if (mounted && index != null) {
      setState(() => selectedType = index);
    }
  }

  void _showSnack(String key) {
    if (!mounted) return;
    BudgetStyle.showNotice(
      context,
      AppLocalizations.of(context).translate(key),
    );
  }

  void _showOverlapSnack() {
    if (!mounted) return;
    final isEnglish = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('en');
    BudgetStyle.showNotice(
      context,
      isEnglish
          ? 'This budget overlaps an existing parent or subcategory budget. Edit the existing budget or choose another category.'
          : 'Danh mục này bị trùng phạm vi với ngân sách cha hoặc con đã có. Hãy sửa ngân sách đã có hiện tại hoặc chọn danh mục khác.',
      warningNotice: true,
    );
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: BudgetStyle.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: BudgetStyle.background(context),
        titleSpacing: 0,
        leadingWidth: 78,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: FinanceToolbarButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: Icons.arrow_back_rounded,
          onPressed: isLoading ? null : () => Navigator.maybePop(context),
        ),
        title: Text(
          AppLocalizations.of(context).translate('add_budget'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isLoading) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  BudgetCard(
                    selectedType: selectedType,
                    limitController: _limitController,
                    onTypeTap: isLoading ? () {} : _openTypeSelector,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: FinanceActionButton(
                      onPressed: isLoading ? null : _saveBudget,
                      label: AppLocalizations.of(
                        context,
                      ).translate('save_budget'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
