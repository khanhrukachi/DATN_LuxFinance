import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/core/constants/function/loading_overlay.dart';
import 'package:personal_financial_management/features/main/budget/add_budget/add_budget_screen.dart';
import 'package:personal_financial_management/features/main/budget/edit_budget/edit_budget_screen.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_item.dart';
import 'package:personal_financial_management/features/main/budget/widget/total_budget_card.dart';
import 'package:personal_financial_management/models/budget.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({Key? key}) : super(key: key);

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  bool isLoading = false;
  List<Map<String, dynamic>> budgetItems = [];

  @override
  void initState() {
    super.initState();
    fetchBudgets();
  }

  Future<void> fetchBudgets() async {
    setState(() => isLoading = true);

    final month = DateTime.now().month;
    final year = DateTime.now().year;

    final budgets =
    await SpendingFirebase.getBudgetsOfMonth(month, year);

    List<Map<String, dynamic>> items = [];

    for (Budget budget in budgets) {
      if (budget.limitMoney <= 0) continue;

      final spent =
      await SpendingFirebase.getTotalExpenseOfMonth(
        month: month,
        year: year,
        type: budget.type == 0 ? null : budget.type,
      );

      items.add({
        "budget": budget,
        "type": budget.type,
        "spent": spent,
        "limit": budget.limitMoney,
      });
    }

    setState(() {
      budgetItems = items;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double spentTotal =
    budgetItems.fold(0, (p, e) => p + (e["spent"] as int));
    final double limitTotal =
    budgetItems.fold(0, (p, e) => p + (e["limit"] as int));
    final double progress =
    limitTotal == 0 ? 0 : (spentTotal / limitTotal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('budget')),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: LoadingOverlay(
        isLoading: isLoading,
        child: SafeArea(
          child: budgetItems.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).translate(
                        'no_budget_yet_add_a_new_budget'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).translate(
                        'tap_the_add_button_to_create_budget'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          )
              : Column(
            children: [
              TotalBudgetCard(
                spent: spentTotal,
                limit: limitTotal,
                progress: progress,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: budgetItems.length,
                  itemBuilder: (context, index) {
                    final item = budgetItems[index];
                    final itemProgress =
                    (item["spent"] / item["limit"]).clamp(0.0, 1.0);

                    return BudgetItem(
                      type: item["type"],
                      spent: item["spent"],
                      limit: item["limit"],
                      progress: itemProgress,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditBudgetPage(
                              budget: item["budget"],
                            ),
                          ),
                        );
                        if (result == true) fetchBudgets();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
