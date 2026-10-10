import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/budget/widget/budget_style.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

/// Returns every expense type covered by a budget category, including the
/// selected category itself. Type 0 is the overall expense budget.
Set<int> budgetCategoryScope(int selectedType) {
  if (selectedType < 0 || selectedType >= listType.length) return <int>{};

  final root = Map<String, dynamic>.from(listType[0] as Map);
  final expenseRootId = root['id']?.toString() ?? 'expense';
  final selected = Map<String, dynamic>.from(listType[selectedType] as Map);
  final selectedId = selected['id']?.toString();

  bool belongsToExpense(int index) {
    if (index == 0) return true;
    final visited = <String>{};
    var current = Map<String, dynamic>.from(listType[index] as Map);
    while (true) {
      final parentId = current['parent']?.toString() ?? '';
      if (parentId == expenseRootId) return true;
      if (parentId.isEmpty || !visited.add(parentId)) return false;
      final parentIndex = listType.indexWhere(
            (item) => item['id']?.toString() == parentId,
      );
      if (parentIndex < 0) return false;
      current = Map<String, dynamic>.from(listType[parentIndex] as Map);
    }
  }

  if (selectedType == 0) {
    return <int>{
      for (var i = 0; i < listType.length; i++)
        if (belongsToExpense(i)) i,
    };
  }

  final scope = <int>{selectedType};
  if (selectedId == null) return scope;

  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 1; i < listType.length; i++) {
      if (scope.contains(i) || !belongsToExpense(i)) continue;
      final parentId = listType[i]['parent']?.toString() ?? '';
      final parentIndex = listType.indexWhere(
            (item) => item['id']?.toString() == parentId,
      );
      if (scope.contains(parentIndex)) {
        scope.add(i);
        changed = true;
      }
    }
  }
  return scope;
}

bool budgetTypesOverlap(int firstType, int secondType) {
  final firstScope = budgetCategoryScope(firstType);
  final secondScope = budgetCategoryScope(secondType);
  return firstScope.any(secondScope.contains);
}

class BudgetTypeSelector extends StatefulWidget {
  final int? selectedType;

  const BudgetTypeSelector({Key? key, this.selectedType}) : super(key: key);

  @override
  State<BudgetTypeSelector> createState() => _BudgetTypeSelectorState();
}

class _BudgetTypeSelectorState extends State<BudgetTypeSelector> {
  final Set<String> _expandedCategories = <String>{};

  bool _isParent(Map item) =>
      item['isParent'] == true || item['isParent']?.toString() == 'true';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);
    final expenseRootId = listType[0]['id']?.toString() ?? 'expense';
    final parentIndexes = <int>[];
    for (var i = 1; i < listType.length; i++) {
      final item = listType[i];
      if (item['parent']?.toString() == expenseRootId && _isParent(item)) {
        parentIndexes.add(i);
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: BudgetStyle.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BudgetStyle.text(context).withOpacity(.18),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.translate('select_category'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                localizations.translate('budget_choose_scope'),
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  _categoryTile(
                    context,
                    index: 0,
                    selectedType: widget.selectedType,
                    isParent: false,
                    isOverall: true,
                  ),
                  Divider(height: 8, color: BudgetStyle.teal.withOpacity(.08)),
                  for (final index in parentIndexes) ...[
                    _parentTile(context, index, widget.selectedType),
                    Divider(height: 8, color: BudgetStyle.teal.withOpacity(.08)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _parentTile(BuildContext context, int index, int? selectedType) {
    final item = listType[index];
    final id = item['id']?.toString() ?? '$index';
    final expanded = _expandedCategories.contains(id);
    final children = <int>[];
    for (var i = 1; i < listType.length; i++) {
      if (listType[i]['parent']?.toString() == id && !_isParent(listType[i])) {
        children.add(i);
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _categoryTile(
                context,
                index: index,
                selectedType: selectedType,
                isParent: true,
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).translate(expanded ? 'budget_collapse_children' : 'budget_show_children'),
              color: BudgetStyle.accent(context),
              onPressed: () => setState(() {
                if (expanded) {
                  _expandedCategories.remove(id);
                } else {
                  _expandedCategories.add(id);
                }
              }),
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ),
          ],
        ),
        if (expanded)
          for (final childIndex in children)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: _categoryTile(
                context,
                index: childIndex,
                selectedType: selectedType,
                isParent: false,
              ),
            ),
      ],
    );
  }

  Widget _categoryTile(BuildContext context, {
    required int index,
    required int? selectedType,
    required bool isParent,
    bool isOverall = false,
  }) {
    final item = listType[index];
    final title = AppLocalizations.of(context).translate(item['title']?.toString() ?? 'other');
    final image = item['image']?.toString();
    final selected = selectedType == index;
    final prominent = isParent || isOverall;
    final accent = BudgetStyle.accent(context);
    final tr = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: selected
            ? (BudgetStyle.dark(context) ? const Color(0xFF16463F) : const Color(0xFFDCF9F1))
            : BudgetStyle.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: BudgetStyle.teal.withOpacity(selected ? .5 : .16))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: () => Navigator.pop(context, index),
          splashColor: BudgetStyle.teal.withOpacity(.14),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 42, height: 42, padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: prominent ? null : BudgetStyle.teal.withOpacity(.10),
                    gradient: prominent ? BudgetStyle.gradient : null,
                    borderRadius: BorderRadius.circular(14)),
                child: image == null || image.isEmpty
                    ? Icon(isOverall ? Icons.account_balance_wallet_outlined
                    : isParent ? Icons.folder_rounded : Icons.label_outline_rounded,
                    color: prominent ? BudgetStyle.ink : accent, size: 22)
                    : Image.asset(image, errorBuilder: (_, __, ___) => Icon(Icons.category_outlined,
                    color: prominent ? BudgetStyle.ink : accent))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, height: 1.4,
                  fontWeight: prominent ? FontWeight.w700 : FontWeight.w500,
                  color: BudgetStyle.text(context))),
              if (isOverall || isParent) ...[
                const SizedBox(height: 4),
                Text(tr.translate(isOverall ? 'budget_scope_overall' : 'budget_scope_parent'),
                    style: TextStyle(fontSize: 11, height: 1.4, color: BudgetStyle.muted(context))),
              ],
            ])),
            if (selected) ...[const SizedBox(width: 8), Icon(Icons.check_circle_rounded, color: accent, size: 22)],
          ])),
        ),
      ),
    );
  }

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');
}
