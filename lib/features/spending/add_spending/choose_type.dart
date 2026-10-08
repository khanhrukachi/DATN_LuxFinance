import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ChooseType extends StatefulWidget {
  const ChooseType({Key? key, required this.action}) : super(key: key);
  final Function(int, int, String?, Map<String, String>) action;

  @override
  State<ChooseType> createState() => _ChooseTypeState();
}

class _ChooseTypeState extends State<ChooseType>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final search = TextEditingController();
  int selectedTab = 0;

  static const Map<String, String> _searchAliases = {
    'move': 'di chuyển di chuyen transportation transport move',
  };

  static const Map<String, String> _diacriticMap = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    'đ': 'd',
  };

  final expenseColors = <String, Color>{
    'expense_living': const Color(0xff4F7CFF),
    'expense_unexpected': const Color(0xffFF8A4C),
    'expense_fixed': const Color(0xff9B6BFF),
    'investment_saving': const Color(0xff13B981),
    'loan_borrow': const Color(0xffEF596F),
  };

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
    tabs.addListener(() {
      if (!tabs.indexIsChanging) setState(() => selectedTab = tabs.index);
    });
  }

  @override
  void dispose() {
    tabs.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(_tr('choose_category')),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(122),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dark ? Colors.white10 : Colors.black.withOpacity(.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: tabs,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: selectedTab == 0
                        ? const Color(0xff4F7CFF)
                        : const Color(0xff13B981),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: dark ? Colors.white70 : Colors.black54,
                  tabs: [
                    Tab(text: _tr('expense')),
                    Tab(text: _tr('income')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                    fillColor: dark ? Colors.white10 : Colors.black.withOpacity(.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _body(dark),
    );
  }

  Widget _body(bool dark) {
    final keyword = _normalizeSearchText(search.text);
    if (selectedTab == 1) {
      final items = listType.where((e) {
        return e['parent'] == 'income' &&
            e['isParent'] == 'false' &&
            _matchesSearch(e, keyword);
      }).toList();
      return _incomeGrid(items, dark);
    }

    final groups = listType.where((e) {
      return e['parent'] == 'expense' && e['isParent'] == 'true';
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
      return e['parent'] == group['id'] &&
          e['isParent'] == 'false' &&
          _matchesSearch(e, keyword);
    }).toList();
    if (children.isEmpty) return const SizedBox.shrink();
    final color = expenseColors[group['id']] ?? const Color(0xff4F7CFF);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xff20232D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? .18 : .07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(group['image'], color, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_title(group),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Text('${children.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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

  Widget _incomeGrid(List<Map<String, String>> items, bool dark) {
    if (items.isEmpty) return Center(child: Text(_tr('no_category')));
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (_, i) => _incomeCard(items[i], dark),
    );
  }

  Widget _incomeCard(Map<String, String> item, bool dark) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _select(item, 1),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? const Color(0xff202B2A) : const Color(0xffF0FBF7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff13B981).withOpacity(.22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconBox(item['image'], const Color(0xff13B981), size: 48),
            const SizedBox(height: 10),
            Text(_title(item), textAlign: TextAlign.center, style: AppStyles.p),
          ],
        ),
      ),
    );
  }

  Widget _childChip(Map<String, String> item, Color color, bool dark) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _select(item, -1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withOpacity(.07) : color.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item['image'] != null)
              Image.asset(item['image']!, width: 25, height: 25),
            const SizedBox(width: 6),
            Text(_title(item), style: const TextStyle(fontSize: 13)),
          ],
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
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(15),
      ),
      child: path == null
          ? Icon(Icons.category_outlined, color: color)
          : Image.asset(path, fit: BoxFit.contain),
    );
  }

  void _select(Map<String, String> item, int coefficient) {
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
