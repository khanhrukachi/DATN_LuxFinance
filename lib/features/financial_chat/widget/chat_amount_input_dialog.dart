import 'package:flutter/material.dart';

import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class ChatAmountInputDialog extends StatelessWidget {
  const ChatAmountInputDialog({
    super.key,
    required this.controller,
    required this.field,
  });

  final TextEditingController controller;
  final String field;

  @override
  Widget build(BuildContext context) {
    final titleKey = field == 'available_balance'
        ? 'financial_chat_available_balance_title'
        : 'financial_chat_target_amount_title';
    return AlertDialog(
      title: Text(AppLocalizations.of(context).translate(titleKey)),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          suffixText: AppLocalizations.of(context).translate('financial_chat_currency_code'),
          hintText: AppLocalizations.of(context).translate('financial_chat_amount_hint'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).translate('financial_chat_skip')),
        ),
        TextButton(
          onPressed: () {
            final amount = double.tryParse(
              controller.text.replaceAll(RegExp(r'[.,\s]'), ''),
            );
            if (amount != null && amount.isFinite && amount >= 0) {
              Navigator.pop(context, amount);
            }
          },
          child: Text(AppLocalizations.of(context).translate('financial_chat_confirm')),
        ),
      ],
    );
  }
}
