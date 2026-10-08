import 'package:flutter/material.dart';
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
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
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
              _isEnglish(context)
                  ? 'Choose an overall, parent, or subcategory budget.'
                  : 'Chọn ngân sách tổng, theo danh mục cha hoặc danh mục con.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: [
                _categoryTile(
                  context,
                  index: 0,
                  selectedType: widget.selectedType,
                  isParent: false,
                  isOverall: true,
                ),
                const Divider(height: 1),
                for (final index in parentIndexes) ...[
                  _parentTile(context, index, widget.selectedType),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
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
              tooltip: expanded ? 'Collapse subcategories' : 'Show subcategories',
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
              padding: const EdgeInsets.only(left: 28),
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

  Widget _categoryTile(
      BuildContext context, {
        required int index,
        required int? selectedType,
        required bool isParent,
        bool isOverall = false,
      }) {
    final item = listType[index];
    final titleKey = item['title']?.toString() ?? 'other';
    final imagePath = item['image']?.toString();
    final title = AppLocalizations.of(context).translate(titleKey);
    final selected = selectedType == index;
    final color = selected ? Colors.blueAccent : Colors.blueGrey;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: isParent ? 8 : 12),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.12),
        ),
        padding: const EdgeInsets.all(9),
        child: imagePath == null
            ? Icon(Icons.category_outlined, color: color)
            : Image.asset(
          imagePath,
          errorBuilder: (_, __, ___) => Icon(Icons.category_outlined, color: color),
        ),
      ),
      title: Text(title, style: TextStyle(fontWeight: isParent ? FontWeight.w600 : FontWeight.normal)),
      subtitle: isOverall
          ? Text(_isEnglish(context) ? 'Includes every expense category' : 'Bao gồm tất cả danh mục chi tiêu')
          : isParent
          ? Text(_isEnglish(context) ? 'Includes this group and its subcategories' : 'Bao gồm nhóm này và các danh mục con')
          : null,
      trailing: selected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
      onTap: () => Navigator.pop(context, index),
    );
  }

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');
}
