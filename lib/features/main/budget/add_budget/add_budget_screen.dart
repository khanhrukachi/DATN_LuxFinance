import 'package:flutter/material.dart';

import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_card.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_type_selector.dart';
import 'package:personal_financial_management/models/budget.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import '../../../../core/constants/function/loading_animation.dart';

class AddBudgetPage extends StatefulWidget {
  const AddBudgetPage({Key? key}) : super(key: key);

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
        int.tryParse(_limitController.text.replaceAll(',', '')) ?? 0;

    if (limit <= 0) {
      _showSnack('budget_limit_must_be_greater_than_zero');
      return;
    }

    setState(() => isLoading = true);

    try {
      final month = DateTime.now().month;
      final year = DateTime.now().year;

      // 🔍 check trùng budget
      final existingBudgets =
      await SpendingFirebase.getBudgetsOfMonth(month, year);

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

    if (index != null) {
      setState(() => selectedType = index);
    }
  }

  void _showSnack(String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate(key)),
      ),
    );
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
        title: Text(
          AppLocalizations.of(context).translate('add_budget'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: BudgetCard(
                    selectedType: selectedType,
                    limitController: _limitController,
                    onTypeTap: _openTypeSelector,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _saveBudget,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      AppLocalizations.of(context)
                          .translate('save_budget'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🔥 LOADING Y HỆT EDIT
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                alignment: Alignment.center,
                child: RotationAnimationWidget(),
              ),
            ),
        ],
      ),
    );
  }
}
