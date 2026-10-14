import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.backgroundColor,
    required this.onChooseCategory,
    required this.onClear,
    required this.canClear,
    required this.canChooseCategory,
  });

  final Color backgroundColor;
  final VoidCallback onChooseCategory;
  final VoidCallback onClear;
  final bool canClear;
  final bool canChooseCategory;

  static const _cyan = Color(0xFF00D2FF);
  static const _teal = Color(0xFF2DD8C6);
  static const _gradient = LinearGradient(
    colors: [_cyan, _teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    String translate(String key) => AppLocalizations.of(context).translate(key);
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Color(0xFF073D43),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('chat_title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  translate('chat_subtitle'),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withOpacity(.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: translate('chat_category_title'),
          onPressed: canChooseCategory ? onChooseCategory : null,
          icon: const Icon(Icons.category_outlined),
        ),
        IconButton(
          tooltip: translate('chat_clear'),
          onPressed: canClear ? onClear : null,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }
}
