import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_card.dart';
import 'package:personal_financial_management/models/budget.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import '../../../../core/constants/function/loading_animation.dart';

class EditBudgetPage extends StatefulWidget {
  final Budget budget;

  const EditBudgetPage({Key? key, required this.budget}) : super(key: key);

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
    limitController = TextEditingController(text: widget.budget.limitMoney.toString());
  }

  @override
  void dispose() {
    limitController.dispose();
    super.dispose();
  }

  Future<void> _updateBudget() async {
    final limit = int.tryParse(limitController.text.replaceAll(',', '')) ?? 0;
    if (limit <= 0) {
      _showSnack(AppLocalizations.of(context).translate('invalid_limit'));
      return;
    }

    setState(() => isLoading = true);
    try {
      await SpendingFirebase.updateBudget(
        budget: widget.budget,
        newLimit: limit,
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack(AppLocalizations.of(context).translate('budget_not_exist'));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteBudget() async {
    final local = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
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
                    fontSize: 20,
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
                          backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
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

    if (confirmed != true) return;

    setState(() => isLoading = true);

    await SpendingFirebase.deleteBudget(
      type: widget.budget.type,
      month: widget.budget.month,
      year: widget.budget.year,
    );

    setState(() => isLoading = false);
    Navigator.pop(context, true);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('edit_budget')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: isLoading ? null : _deleteBudget,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                BudgetCard(
                  selectedType: selectedType,
                  limitController: limitController,
                  onTypeTap: () {},
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _updateBudget,
                    child: Text(
                      AppLocalizations.of(context).translate('update_budget'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: RotationAnimationWidget(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
