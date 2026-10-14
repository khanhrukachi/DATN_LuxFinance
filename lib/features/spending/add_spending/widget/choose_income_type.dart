import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ChooseIncomeType extends StatefulWidget {
  const ChooseIncomeType({super.key, required this.action});

  final Function(int, int, String?, Map<String, String>) action;

  @override
  State<ChooseIncomeType> createState() => _ChooseIncomeTypeState();
}

class _ChooseIncomeTypeState extends State<ChooseIncomeType> {
  final TextEditingController search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpendingStyle.background(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: SpendingStyle.background(context),
        title: Text(_tr('income')),
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
      body: _incomeGrid(),
    );
  }

  Widget _incomeGrid() {
    final keyword = _normalizeSearchText(search.text);
    final items = listType.where((item) {
      return isSpendingCategory(item) &&
          item['parent'] == 'income' &&
          item['isParent'] == 'false' &&
          !isDebtCategory(item) &&
          _normalizeSearchText(_title(item)).contains(keyword);
    }).toList();

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
      itemBuilder: (_, index) => _incomeCard(items[index]),
    );
  }

  Widget _incomeCard(Map<String, String> item) {
    return Material(
      color: SpendingStyle.card(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _select(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: SpendingStyle.teal.withOpacity(.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: item['image'] == null
                    ? Icon(
                        Icons.category_outlined,
                        color: SpendingStyle.accent(context),
                      )
                    : Image.asset(
                        item['image']!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.category_outlined,
                          color: SpendingStyle.accent(context),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  _title(item),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(Map<String, String> item) {
    if (!isSpendingCategory(item) || isDebtCategory(item)) return;
    final parent = listType.firstWhere(
      (candidate) => candidate['id'] == item['parent'],
      orElse: () => <String, String>{},
    );
    final selected = Map<String, String>.from(item)
      ..['parentName'] = parent['title'] ?? 'income';
    widget.action(listType.indexOf(item), 1, item['title'], selected);
    Navigator.pop(context);
  }

  String _title(Map<String, String> item) => _tr(item['title'] ?? '');

  String _normalizeSearchText(String value) {
    const replacements = <String, String>{
      'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y', 'đ': 'd',
    };
    final result = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      if (rune >= 0x0300 && rune <= 0x036f) continue;
      final character = String.fromCharCode(rune);
      result.write(replacements[character] ?? character);
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
