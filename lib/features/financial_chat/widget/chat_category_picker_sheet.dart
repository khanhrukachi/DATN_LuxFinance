import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'chat_category_tile.dart';

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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? _teal : const Color(0xFF14988F);
    String translate(String key) => AppLocalizations.of(context).translate(key);
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
                      translate('chat_category_title'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
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
                itemCount: categoryCatalog.length,
                itemBuilder: (context, index) {
                  final item = categoryCatalog[index];
                  final name = '${item['display_name'] ?? item['id']}';
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
