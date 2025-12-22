import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_card.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_type_selector.dart';
import 'package:personal_financial_management/models/budget.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class AddBudgetPage extends StatefulWidget {
  const AddBudgetPage({Key? key}) : super(key: key);

  @override
  State<AddBudgetPage> createState() => _AddBudgetPageState();
}

class _AddBudgetPageState extends State<AddBudgetPage> {
  int? selectedType;
  final TextEditingController _limitController = TextEditingController();

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _saveBudget() async {
    if (selectedType == null || _limitController.text.isEmpty) return;

    final limit =
        int.tryParse(_limitController.text.replaceAll(',', '')) ?? 0;
    if (limit <= 0) return;

    final budget = Budget(
      type: selectedType!,
      month: DateTime.now().month,
      year: DateTime.now().year,
      limitMoney: limit,
    );

    await SpendingFirebase.addOrUpdateBudget(budget);
    Navigator.pop(context, true);
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('add_budget')),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            BudgetCard(
              selectedType: selectedType,
              limitController: _limitController,
              onTypeTap: _openTypeSelector,
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saveBudget,
                child: Text(
                  AppLocalizations.of(context).translate('save_budget'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}