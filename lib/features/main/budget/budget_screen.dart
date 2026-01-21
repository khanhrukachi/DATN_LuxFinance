import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/budget/add_budget/add_budget_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/main/budget/edit_budget/edit_budget_screen.dart';
import 'package:personal_financial_management/features/main/budget/widget/total_budget_card.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_item.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({Key? key}) : super(key: key);

  @override
  State<BudgetPage> createState() => BudgetPageState();
}

class BudgetPageState extends State<BudgetPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  List<Map<String, dynamic>> budgetItems = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchBudgets();
  }

  Future<void> fetchBudgets() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    final month = DateTime.now().month;
    final year = DateTime.now().year;

    final budgets = await SpendingFirebase.getBudgetsOfMonth(month, year);

    final futures = budgets
        .where((b) => b.limitMoney > 0)
        .map((budget) async {
      final spent = await SpendingFirebase.getTotalExpenseOfMonth(
        month: month,
        year: year,
        type: budget.type == 0 ? null : budget.type,
      );

      return {
        "budget": budget,
        "type": budget.type,
        "spent": spent,
        "limit": budget.limitMoney,
      };
    }).toList();

    final items = await Future.wait(futures);

    if (!mounted) return;

    setState(() {
      budgetItems = items;
      isLoading = false;
    });
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double spentTotal =
    budgetItems.fold(0.0, (p, e) => p + e["spent"]);
    final double limitTotal =
    budgetItems.fold(0.0, (p, e) => p + e["limit"]);
    final double progress =
    limitTotal == 0 ? 0 : (spentTotal / limitTotal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('budget')),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
            children: [
              if (!isLoading && budgetItems.isNotEmpty) ...[
                TotalBudgetCard(
                  spent: spentTotal,
                  limit: limitTotal,
                  progress: progress,
                  isLoading: isLoading,
                ),
                const SizedBox(height: 12),
              ],

              Expanded(
                child: isLoading
                    ? _buildLoading()
                    : budgetItems.isEmpty
                    ? _buildEmptyWithButton(context)
                    : _buildBudgetList(),
              ),
            ]

        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 5,
      itemBuilder: (_, __) => const BudgetItem(
        type: 0,
        spent: 0,
        limit: 0,
        progress: 0.0,
        isLoading: true,
      ),
    );
  }

  Widget _buildBudgetList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: budgetItems.length,
      itemBuilder: (context, index) {
        final item = budgetItems[index];
        final progress =
        (item["spent"] / item["limit"]).clamp(0.0, 1.0);

        return BudgetItemFuture(
          budget: item["budget"],
          spent: item["spent"],
          limit: item["limit"],
          progress: progress,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditBudgetPage(budget: item["budget"]),
              ),
            );
            if (result == true) fetchBudgets();
          },
        );
      },
    );
  }


  // ===================== EMPTY STATE =================
  Widget _buildEmptyWithButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
              AppLocalizations.of(context)
                  .translate('no_budget_yet_add_a_new_budget'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  backgroundColor:
                  isDark ? Colors.green.shade600 : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddBudgetPage(),
                    ),
                  );
                  if (result == true) fetchBudgets();
                },
                child: Text(
                  AppLocalizations.of(context)
                      .translate('add_budget'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== WRAPPER FOR BUDGET ITEM =================
class BudgetItemFuture extends StatelessWidget {
  final dynamic budget;
  final int spent;
  final int limit;
  final double progress;
  final VoidCallback? onTap;

  const BudgetItemFuture({
    Key? key,
    required this.budget,
    required this.spent,
    required this.limit,
    required this.progress,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BudgetItem(
      type: budget.type,
      spent: spent,
      limit: limit,
      progress: progress,
      onTap: onTap,
    );
  }
}
