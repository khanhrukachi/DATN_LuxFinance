import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';
import 'package:personal_financial_management/features/main/budget/add_budget/add_budget_screen.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/features/main/budget/edit_budget/edit_budget_screen.dart';
import 'package:personal_financial_management/features/main/budget/widget/total_budget_card.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_item.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

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

  Future<void> _addBudget() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddBudgetPage()),
    );
    if (result == true) await fetchBudgets();
  }

  Future<void> fetchBudgets() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    final month = DateTime.now().month;
    final year = DateTime.now().year;

    final budgets = await SpendingFirebase.getBudgetsOfMonth(month, year);

    final futures = budgets.where((b) => b.limitMoney > 0).map((budget) async {
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

    final double spentTotal = budgetItems.fold(0.0, (p, e) => p + e["spent"]);
    final double limitTotal = budgetItems.fold(0.0, (p, e) => p + e["limit"]);
    final double progress = limitTotal == 0 ? 0 : (spentTotal / limitTotal);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const teal = Color(0xFF2DD8C6);
    final actionColor = isDark ? teal : const Color(0xFF14988F);

    return Scaffold(
      backgroundColor: BudgetStyle.background(context),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('budget'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: BudgetStyle.background(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 0, right: 16),
            child: Tooltip(
              message: AppLocalizations.of(context).translate('add_budget'),
              child: Material(
                color: teal.withOpacity(isDark ? .15 : .13),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _addBudget,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.add_rounded,
                      color: actionColor,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          ],
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
        final progress = (item["spent"] / item["limit"]);

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 60,
              color: BudgetStyle.accent(context),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(
                context,
              ).translate('no_budget_yet_add_a_new_budget'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: BudgetStyle.muted(context),
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
    super.key,
    required this.budget,
    required this.spent,
    required this.limit,
    required this.progress,
    this.onTap,
  });

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
