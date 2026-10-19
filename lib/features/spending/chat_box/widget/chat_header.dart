import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'chat_style.dart';
import 'chat_avatar.dart';
import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';

class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatHeader({super.key, required this.saving, required this.hasPendingTransaction, required this.onBack, required this.onClear});
  final bool saving;
  final bool hasPendingTransaction;
  final VoidCallback onBack;
  final VoidCallback onClear;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    final style = ChatStyle(context);
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: style.pageColor,
      foregroundColor: style.textColor,
      titleSpacing: 0,
      centerTitle: false,
      leadingWidth: 76,
      surfaceTintColor: Colors.transparent,
      leading: FinanceToolbarButton(
        tooltip: AppLocalizations.of(context).translate('financial_secretary_back'),
        icon: Icons.arrow_back_rounded,
        onPressed: saving ? null : onBack,
      ),
      title: Row(
        children: [
          ChatAvatar(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).translate('financial_secretary_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FinanceToolbarButton(
          tooltip: AppLocalizations.of(context).translate('financial_secretary_clear_chat'),
          onPressed: saving ? null : onClear,
          icon: Icons.delete_outline_rounded,
        ),
        const SizedBox(width: 14),
      ],
    );
  }
}
