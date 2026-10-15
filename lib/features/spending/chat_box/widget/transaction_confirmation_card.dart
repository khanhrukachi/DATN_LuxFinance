import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:intl/intl.dart';

import '../model/chat_intent.dart';
import 'chat_detail_row.dart';
import 'package:personal_financial_management/core/constants/list.dart';

class TransactionConfirmationCard extends StatelessWidget {
  final ChatTransactionDraft draft;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;

  const TransactionConfirmationCard({
    super.key,
    required this.draft,
    required this.onConfirm,
    required this.onCancel,
  });


  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final money = NumberFormat.currency(
      locale: Localizations.localeOf(context).languageCode == 'vi'
          ? 'vi_VN'
          : 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    ).format(draft.amount);
    final isIncome = draft.kind == ChatTransactionKind.income;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF172A30) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF2DD8C6).withOpacity(.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).translate('financial_secretary_confirmation_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ChatDetailRow(AppLocalizations.of(context).translate('financial_secretary_transaction_type'),
              isIncome
                  ? AppLocalizations.of(context).translate('financial_secretary_income')
                  : AppLocalizations.of(context).translate('financial_secretary_expense'),
            ),
            ChatDetailRow(AppLocalizations.of(context).translate('financial_secretary_amount'), money),
            ChatDetailRow(AppLocalizations.of(context).translate('financial_secretary_category'), AppLocalizations.of(context).translate(listType[draft.type]['title'] ?? 'financial_secretary_unknown_category')),
            ChatDetailRow(AppLocalizations.of(context).translate('financial_secretary_date'),
              DateFormat('dd/MM/yyyy').format(draft.date),
            ),
            ChatDetailRow(AppLocalizations.of(context).translate('financial_secretary_time'),
              draft.hasExplicitTime
                  ? DateFormat('HH:mm').format(draft.date)
                  : AppLocalizations.of(context).translate('financial_secretary_not_provided'),
            ),
            ChatDetailRow(AppLocalizations.of(context).translate('financial_secretary_location'),
              draft.location.isEmpty ? AppLocalizations.of(context).translate('financial_secretary_not_provided') : draft.location,
            ),
            ChatDetailRow(AppLocalizations.of(context).translate('financial_secretary_note'),
              draft.note.isEmpty ? AppLocalizations.of(context).translate('financial_secretary_not_provided') : draft.note,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(AppLocalizations.of(context).translate('financial_secretary_cancel')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD8C6),
                      foregroundColor: const Color(0xFF073D43),
                    ),
                    onPressed: onConfirm,
                    child: Text(AppLocalizations.of(context).translate('financial_secretary_save_transaction')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
