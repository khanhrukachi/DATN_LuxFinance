
import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/main/home/widget/home_style.dart';

import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/main/home/view_list_spending_screen.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ItemParentIdWidget extends StatefulWidget {
  const ItemParentIdWidget({Key? key, this.spendingList, this.embedded = false}) : super(key: key);

  final List<Spending>? spendingList;
  final bool embedded;

  @override
  State<ItemParentIdWidget> createState() => _ItemParentIdWidgetState();
}

class _ItemParentIdWidgetState extends State<ItemParentIdWidget> {
  final Set<String> _expandedParents = <String>{};

  @override
  Widget build(BuildContext context) {
    final spendings = widget.spendingList;
    if (spendings == null) return _loading(context);

    final groups = _buildParentGroups(spendings);

    return ListView.builder(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isExpanded = _expandedParents.contains(group.id);

        return Column(
          children: [
            _categoryCard(
              context: context,
              categoryIndex: group.categoryIndex,
              spendings: group.allSpendings,
              isParent: true,
              isExpanded: isExpanded,
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedParents.remove(group.id);
                  } else {
                    _expandedParents.add(group.id);
                  }
                });
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Column(
                children: group.children.map((child) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: _categoryCard(
                      context: context,
                      categoryIndex: child.categoryIndex,
                      spendings: child.spendings,
                      isParent: false,
                      isExpanded: false,
                      onTap: () => _openTransactions(
                        context,
                        child.spendings,
                      ),
                    ),
                  );
                }).toList(),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  List<_ParentSpendingGroup> _buildParentGroups(List<Spending> spendings) {
    final groups = <_ParentSpendingGroup>[];

    for (var parentIndex = 0; parentIndex < listType.length; parentIndex++) {
      final parent = listType[parentIndex];
      final parentId = parent['id'] ?? parent['title'];

      if (parentId == null ||
          parent['isParent'] != 'true' ||
          parentId == 'expense' ||
          parentId == 'current_money') {
        continue;
      }

      final children = <_ChildSpendingGroup>[];
      final parentDirectSpendings = spendings
          .where((spending) => spending.type == parentIndex)
          .toList();

      for (var childIndex = 0; childIndex < listType.length; childIndex++) {
        final child = listType[childIndex];
        if (child['parent'] != parentId) continue;

        final childSpendings = spendings
            .where((spending) => spending.type == childIndex)
            .toList();

        // Chỉ hiện danh mục con có giao dịch trong danh sách hiện tại.
        if (childSpendings.isEmpty) continue;

        children.add(_ChildSpendingGroup(childIndex, childSpendings));
      }

      if (children.isEmpty && parentDirectSpendings.isEmpty) continue;

      final allSpendings = <Spending>[...parentDirectSpendings];
      for (final child in children) {
        allSpendings.addAll(child.spendings);
      }

      groups.add(
        _ParentSpendingGroup(
          id: parentId,
          categoryIndex: parentIndex,
          children: children,
          allSpendings: allSpendings,
        ),
      );
    }

    return groups;
  }

  Widget _categoryCard({required BuildContext context, required int categoryIndex,
    required List<Spending> spendings, required bool isParent,
    required bool isExpanded, required VoidCallback onTap}) {
    final item = listType[categoryIndex];
    return HomeCategoryTile(
      title: AppLocalizations.of(context).translate(item['title'] ?? 'other'),
      image: item['image'], money: spendings.fold<int>(0, (s, e) => s + e.money),
      isParent: isParent, isExpanded: isExpanded, onTap: onTap,
    );
  }

  void _openTransactions(BuildContext context, List<Spending> spendings) {
    Navigator.of(context).push(
      createRoute(
        screen: ViewListSpendingPage(spendingList: spendings),
        begin: const Offset(1, 0),
      ),
    );
  }

  Widget _loading(BuildContext context) => HomeLoadingList(embedded: widget.embedded);
}

class _ParentSpendingGroup {
  final String id;
  final int categoryIndex;
  final List<_ChildSpendingGroup> children;
  final List<Spending> allSpendings;

  const _ParentSpendingGroup({
    required this.id,
    required this.categoryIndex,
    required this.children,
    required this.allSpendings,
  });
}

class _ChildSpendingGroup {
  final int categoryIndex;
  final List<Spending> spendings;

  const _ChildSpendingGroup(this.categoryIndex, this.spendings);
}