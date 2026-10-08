import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/main/home/view_list_spending_screen.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ItemParentIdWidget extends StatefulWidget {
  const ItemParentIdWidget({Key? key, this.spendingList}) : super(key: key);

  final List<Spending>? spendingList;

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
                    padding: const EdgeInsets.only(left: 24),
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

  Widget _categoryCard({
    required BuildContext context,
    required int categoryIndex,
    required List<Spending> spendings,
    required bool isParent,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numberFormat = NumberFormat.decimalPattern('vi');
    final Map<String, dynamic> typeItem = listType[categoryIndex];

    final String titleKey = typeItem['title'] as String;
    final String? imagePath = typeItem['image'] as String?;
    final Color baseColor =
        typeItem['color'] as Color? ?? const Color(0xFF5B7CFA);

    final int totalMoney =
    spendings.fold<int>(0, (sum, item) => sum + item.money);
    final bool isExpense = totalMoney < 0;

    final Color surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final Color textPrimary =
    isDark ? Colors.white : const Color(0xFF1C1C1C);
    final Color accent = isExpense
        ? const Color(0xFFE5533D)
        : const Color(0xFF2FBF71);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isParent ? 18 : 14,
            vertical: isParent ? 16 : 12,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: accent.withOpacity(isDark ? 0.25 : 0.12),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: accent.withOpacity(isParent ? 0.15 : 0.08),
                  blurRadius: isParent ? 16 : 10,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isParent ? 54 : 42,
                height: isParent ? 54 : 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      baseColor.withOpacity(0.30),
                      baseColor.withOpacity(0.08),
                    ],
                  ),
                ),
                child: imagePath != null
                    ? Padding(
                  padding: EdgeInsets.all(isParent ? 12 : 9),
                  child: Image.asset(imagePath),
                )
                    : Icon(Icons.category, color: baseColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate(titleKey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isParent ? 15 : 14,
                    fontWeight: isParent ? FontWeight.w600 : FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                '${isExpense ? "-" : "+"}'
                    '${numberFormat.format(totalMoney.abs())} đ',
                style: TextStyle(
                  fontSize: isParent ? 15 : 14,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isParent
                    ? (isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down)
                    : Icons.chevron_right,
                color: accent,
                size: 26,
              ),
            ],
          ),
        ),
      ),
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

  Widget _loading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final baseShimmer = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightShimmer =
    isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: 5,
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Shimmer.fromColors(
                  baseColor: baseShimmer,
                  highlightColor: highlightShimmer,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: baseShimmer,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _textLoading(
                    Random().nextInt(80) + 80,
                    baseShimmer: baseShimmer,
                    highlightShimmer: highlightShimmer,
                  ),
                ),
                const SizedBox(width: 16),
                _textLoading(
                  Random().nextInt(50) + 60,
                  baseShimmer: baseShimmer,
                  highlightShimmer: highlightShimmer,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _textLoading(
      int width, {
        int height = 16,
        required Color baseShimmer,
        required Color highlightShimmer,
      }) {
    return Shimmer.fromColors(
      baseColor: baseShimmer,
      highlightColor: highlightShimmer,
      child: Container(
        height: height.toDouble(),
        width: width.toDouble(),
        decoration: BoxDecoration(
          color: baseShimmer,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
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