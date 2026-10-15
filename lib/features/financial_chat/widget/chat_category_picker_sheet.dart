import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'chat_category_tile.dart';
import '../utils/chat_category_label.dart';

class ChatCategoryPickerSheet extends StatelessWidget {
  const ChatCategoryPickerSheet({
    super.key,
    required this.categoryCatalog,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> categoryCatalog;
  final ValueChanged<String> onSelect;

  static const _cyan = Color(0xFF00D2FF);
  static const _teal = Color(0xFF2DD8C6);
  static const _gradient = LinearGradient(
    colors: [_cyan, _teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );


  // Hide these groups and their children only in the category picker.
  static const _hiddenCategoryKeys = <String>{
    'loan_borrow',
    'income',
    'loan',
    'pay',
    'pay_interest',
    'borrow',
    'debt_collection',
    'earn_profit',
    'salary',
    'revenue',
    'other_income',
    'money_transferred_to',
  };

  String _categoryKey(Object? value) =>
      value?.toString().trim().toLowerCase() ?? '';

  Iterable<String> _itemKeys(Map<String, dynamic> item) => [
    _categoryKey(item['id']),
    _categoryKey(item['title']),
  ].where((key) => key.isNotEmpty);

  List<Map<String, dynamic>> _visibleCategories() {
    final hidden = <String>{..._hiddenCategoryKeys};
    // Parent references can use either a canonical title or a category ID.
    // Resolve descendants without changing the original catalog or indexes.
    bool changed;
    do {
      changed = false;
      for (final item in categoryCatalog) {
        final keys = _itemKeys(item);
        final parents = [
          _categoryKey(item['parent']),
          _categoryKey(item['parentCategoryId']),
          _categoryKey(item['parentId']),
        ];
        if (keys.any(hidden.contains) || parents.any(hidden.contains)) {
          for (final key in keys) {
            if (hidden.add(key)) changed = true;
          }
        }
      }
    } while (changed);

    return categoryCatalog
        .where((item) => !_itemKeys(item).any(hidden.contains))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategories = _visibleCategories();
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final parentBackground = dark
        ? const Color(0xFF163A46)
        : const Color(0xFFE1F7FF);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .72,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withOpacity(.18),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: _gradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      color: Color(0xFF073D43),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).translate('financial_chat_category_title'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context).translate('financial_chat_close'),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.onSurface.withOpacity(.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: visibleCategories.length,
                itemBuilder: (context, index) {
                  final item = visibleCategories[index];
                  final name = chatCategoryLabel(context, item['title'] ?? item['id'], catalog: categoryCatalog);
                  return ChatCategoryTile(
                    name: name,
                    isParent: item['isParent'] == true,
                    parentBackground: parentBackground,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(name);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
