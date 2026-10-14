import 'package:flutter/material.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ChooseSpendingType extends StatefulWidget {
  const ChooseSpendingType({super.key, required this.action});

  final Function(int, int, String?, Map<String, String>) action;
  
  @override
  State<ChooseSpendingType> createState() => _ChooseSpendingTypeState();
}

class _ChooseSpendingTypeState extends State<ChooseSpendingType> {
  final search = TextEditingController();

  static const Map<String, String> _searchAliases = {
    'move': 'di chuyển di chuyen transportation transport move',
  };

  static const Map<String, String> _diacriticMap = {
    'à': 'a',
    'á': 'a',
    'ả': 'a',
    'ã': 'a',
    'ạ': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ậ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'ặ': 'a',
    'è': 'e',
    'é': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ẹ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ệ': 'e',
    'ì': 'i',
    'í': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ị': 'i',
    'ò': 'o',
    'ó': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ọ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ộ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ợ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ụ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ự': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'ỵ': 'y',
    'đ': 'd',
  };

  final expenseColors = <String, Color>{
    'expense_living': SpendingStyle.teal,
    'expense_unexpected': SpendingStyle.teal,
    'expense_fixed': SpendingStyle.teal,
    'investment_saving': SpendingStyle.teal,
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: SpendingStyle.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: SpendingStyle.background(context),
        title: Text(_tr('choose_category')),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                      ),
                hintText: _tr('search_category'),
                filled: true,
                fillColor: SpendingStyle.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _body(dark),
    );
  }

  Widget _body(bool dark) {
    final keyword = _normalizeSearchText(search.text);
    final groups = listType.where((e) {
      return isSpendingCategory(e) &&
          e['parent'] == 'expense' &&
          e['isParent'] == 'true';
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _groupCard(groups[i], dark, keyword),
    );
  }

  Widget _groupCard(Map<String, String> group, bool dark, String keyword) {
    final children = listType.where((e) {
      return isSpendingCategory(e) &&
          e['parent'] == group['id'] &&
          e['isParent'] == 'false' &&
          _matchesSearch(e, keyword);
    }).toList();
    if (children.isEmpty) return const SizedBox.shrink();
    final color = expenseColors[group['id']] ?? SpendingStyle.teal;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: SpendingStyle.decoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(group['image'], color, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _title(group),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${children.length}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children.map((e) => _childChip(e, color, dark)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _childChip(Map<String, String> item, Color color, bool dark) {
    return Material(
      color: SpendingStyle.teal.withOpacity(.08),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _select(item, -1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item['image'] != null) ...[
                Image.asset(
                  item['image']!,
                  width: 25,
                  height: 25,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.label_outline_rounded, size: 25, color: color),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  _title(item),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBox(String? path, Color color, {required double size}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: SpendingStyle.teal.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: path == null
          ? Icon(Icons.category_outlined, color: color)
          : Image.asset(
              path,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.category_outlined, color: color),
            ),
    );
  }

  void _select(Map<String, String> item, int coefficient) {
    if (!isSpendingCategory(item)) return;
    final parent = listType.firstWhere(
      (e) => e['id'] == item['parent'],
      orElse: () => <String, String>{},
    );
    final selected = Map<String, String>.from(item)
      ..['parentName'] = parent['title'] ?? 'income';
    widget.action(listType.indexOf(item), coefficient, item['title'], selected);
    Navigator.pop(context);
  }

  String _title(Map<String, String> item) => _tr(item['title'] ?? '');

  bool _matchesSearch(Map<String, String> item, String normalizedKeyword) {
    if (normalizedKeyword.isEmpty) return true;

    final titleKey = item['title'] ?? '';
    final searchableText = [
      _title(item),
      titleKey,
      _searchAliases[titleKey] ?? '',
    ].join(' ');

    return _normalizeSearchText(searchableText).contains(normalizedKeyword);
  }

  String _normalizeSearchText(String value) {
    final result = StringBuffer();

    for (final rune in value.toLowerCase().runes) {
      // Bỏ dấu tổ hợp Unicode nếu chuỗi được nhập ở dạng decomposed.
      if (rune >= 0x0300 && rune <= 0x036f) continue;

      final character = String.fromCharCode(rune);
      result.write(_diacriticMap[character] ?? character);
    }

    return result.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _tr(String key) {
    try {
      return AppLocalizations.of(context).translate(key);
    } catch (_) {
      return key;
    }
  }
}
