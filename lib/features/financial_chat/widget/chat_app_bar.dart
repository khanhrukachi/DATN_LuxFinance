import 'package:flutter/material.dart';
import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'chat_assistant_avatar.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.backgroundColor,
    required this.onChooseCategory,
    required this.onClear,
    required this.canClear,
    required this.canChooseCategory,
    this.onBack,
  });

  final Color backgroundColor;
  final VoidCallback onChooseCategory;
  final VoidCallback onClear;
  final bool canClear;
  final bool canChooseCategory;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: backgroundColor,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    titleSpacing: 0,
    leadingWidth: 76,
    leading: FinanceToolbarButton(
      tooltip: AppLocalizations.of(context).translate('financial_chat_back'),
      icon: Icons.arrow_back_rounded,
      onPressed: onBack ?? () { Navigator.maybePop(context); },
    ),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ChatAssistantAvatar(size: 34),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            AppLocalizations.of(context).translate('financial_chat_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
    actions: [
      FinanceToolbarButton(
        tooltip: AppLocalizations.of(context).translate('financial_chat_category_title'),
        icon: Icons.category_outlined,
        onPressed: canChooseCategory ? onChooseCategory : null,
      ),
      FinanceToolbarButton(
        tooltip: AppLocalizations.of(context).translate('financial_chat_clear_conversation'),
        icon: Icons.delete_outline_rounded,
        onPressed: canClear ? onClear : null,
      ),
      const SizedBox(width: 16),
    ],
  );
}
