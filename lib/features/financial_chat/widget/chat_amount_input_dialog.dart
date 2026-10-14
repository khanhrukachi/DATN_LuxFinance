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
    final localizations = AppLocalizations.of(context);
    final titleKey = field == 'available_balance'
        ? 'chat_available_balance_title'
        : 'chat_target_amount_title';
    return AlertDialog(
      title: Text(localizations.translate(titleKey)),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(suffixText: 'VND'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.translate('chat_skip')),
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
          child: Text(localizations.translate('chat_confirm')),
        ),
      ],
    );
  }
}
