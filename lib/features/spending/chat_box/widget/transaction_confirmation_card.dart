import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:intl/intl.dart';

import 'chat_intent.dart';

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

  String _t(BuildContext context, String key) => AppLocalizations.of(context).translate(key);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final money = NumberFormat.currency(locale: Localizations.localeOf(context).languageCode == 'vi' ? 'vi_VN' : 'en_US', symbol: '₫', decimalDigits: 0).format(draft.amount);
    final isIncome = draft.kind == ChatTransactionKind.income;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF172A30) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: const Color(0xFF2DD8C6).withOpacity(.25))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t(context, 'transaction_chat_15'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _row(context, _t(context, 'transaction_chat_16'), isIncome ? _t(context, 'transaction_chat_17') : _t(context, 'transaction_chat_18')),
          _row(context, _t(context, 'transaction_chat_19'), money),
          _row(context, _t(context, 'transaction_chat_20'), draft.typeName),
          _row(context, _t(context, 'transaction_chat_21'), DateFormat('dd/MM/yyyy').format(draft.date)),
          _row(context, _t(context, 'transaction_chat_22'), draft.hasExplicitTime ? DateFormat('HH:mm').format(draft.date) : '—'),
          _row(context, _t(context, 'transaction_chat_23'), draft.location.isEmpty ? '—' : draft.location),
          _row(context, _t(context, 'transaction_chat_24'), draft.note.isEmpty ? '—' : draft.note),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: onCancel, child: Text(_t(context, 'transaction_chat_25')))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2DD8C6), foregroundColor: const Color(0xFF073D43)), onPressed: onConfirm, child: Text(_t(context, 'transaction_chat_26')))),
          ]),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 88, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value, style: const TextStyle(height: 1.4))),
      ]),
    );
  }
}
