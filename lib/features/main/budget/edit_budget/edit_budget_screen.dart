import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_card.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_type_selector.dart';
import 'package:personal_financial_management/models/budget.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class EditBudgetPage extends StatefulWidget {
  final Budget budget;

  const EditBudgetPage({super.key, required this.budget});

  @override
  State<EditBudgetPage> createState() => _EditBudgetPageState();
}

class _EditBudgetPageState extends State<EditBudgetPage> {
  late int selectedType;
  late TextEditingController limitController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedType = widget.budget.type;
    limitController = TextEditingController(
      text: widget.budget.limitMoney.toString(),
    );
  }

  @override
  void dispose() {
    limitController.dispose();
    super.dispose();
  }

  Future<void> _updateBudget() async {
    if (isLoading) return;
    final limit =
        int.tryParse(limitController.text.replaceAll(RegExp(r'[.,\s]'), '')) ??
            0;
    if (limit <= 0) {
      _showSnack(AppLocalizations.of(context).translate('invalid_limit'));
      return;
    }

    setState(() => isLoading = true);
    try {
      final existingBudgets = await SpendingFirebase.getBudgetsOfMonth(
        widget.budget.month,
        widget.budget.year,
      );
      if (!mounted) return;
      for (final existing in existingBudgets) {
        if (existing.type == widget.budget.type) continue;
        if (budgetTypesOverlap(existing.type, selectedType)) {
          _showOverlapSnack();
          return;
        }
      }

      if (selectedType == widget.budget.type) {
        await SpendingFirebase.updateBudget(
          budget: widget.budget,
          newLimit: limit,
        );
      } else {
        // Write the new category first so a failed write leaves the old budget intact.
        await SpendingFirebase.addOrUpdateBudget(
          Budget(
            type: selectedType,
            month: widget.budget.month,
            year: widget.budget.year,
            limitMoney: limit,
          ),
        );
        await SpendingFirebase.deleteBudget(
          type: widget.budget.type,
          month: widget.budget.month,
          year: widget.budget.year,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(AppLocalizations.of(context).translate('budget_not_exist'));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _openTypeSelector() async {
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetTypeSelector(selectedType: selectedType),
    );
    if (mounted && index != null) setState(() => selectedType = index);
  }

  void _showOverlapSnack() {
    if (!mounted) return;
    final isEnglish = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('en');
    BudgetStyle.showNotice(
      context,
      isEnglish
          ? 'This budget overlaps an existing parent or subcategory budget. Choose another category.'
          : 'Danh mục này bị trùng phạm vi với ngân sách cha hoặc con khác. Hãy chọn danh mục khác.',
      warningNotice: true,
    );
  }

  Future<void> _deleteBudget() async {
    if (isLoading) return;
    final local = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: BudgetStyle.card(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  local.translate('delete_budget'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  local.translate('delete_budget_confirm'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.grey[700]
                              : Colors.grey[300],
                          foregroundColor: isDark ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(local.translate('cancel')),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(local.translate('delete')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => isLoading = true);
    try {
      await SpendingFirebase.deleteBudget(
        type: widget.budget.type,
        month: widget.budget.month,
        year: widget.budget.year,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        _showSnack(
          AppLocalizations.of(context).translate('something_went_wrong'),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    BudgetStyle.showNotice(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: BudgetStyle.background(context),
      appBar: AppBar(
        backgroundColor: BudgetStyle.background(context),
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 76,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: FinanceToolbarButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: Icons.arrow_back_rounded,
          onPressed: isLoading ? null : () => Navigator.maybePop(context),
        ),
        title: Text(
          AppLocalizations.of(context).translate('edit_budget'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18
          ),
        ),
        actions: [
          FinanceToolbarButton(
            tooltip: AppLocalizations.of(context).translate('delete'),
            icon: Icons.delete_outline_rounded,
            color: Colors.red,
            onPressed: isLoading ? null : _deleteBudget,
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
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
                    limitController: limitController,
                    onTypeTap: isLoading ? () {} : _openTypeSelector,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: FinanceActionButton(
                      onPressed: isLoading ? null : _updateBudget,
                      label: AppLocalizations.of(
                        context,
                      ).translate('update_budget'),
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
