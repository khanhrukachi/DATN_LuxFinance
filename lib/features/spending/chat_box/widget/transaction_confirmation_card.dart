import 'package:flutter/material.dart';
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

  String _t(BuildContext context, String vi, String en) =>
      Localizations.localeOf(context).languageCode == 'vi' ? vi : en;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(draft.amount);
    final isIncome = draft.kind == ChatTransactionKind.income;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: dark ? const Color(0xFF303030) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t(context, 'Xác nhận giao dịch', 'Confirm transaction'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _row(context, _t(context, 'Loại', 'Type'), isIncome ? _t(context, 'Thu nhập', 'Income') : _t(context, 'Chi tiêu', 'Expense')),
          _row(context, _t(context, 'Số tiền', 'Amount'), money),
          _row(context, _t(context, 'Danh mục', 'Category'), draft.typeName),
          _row(context, _t(context, 'Ngày', 'Date'), DateFormat('dd/MM/yyyy').format(draft.date)),
          _row(context, _t(context, 'Giờ', 'Time'), draft.hasExplicitTime ? DateFormat('HH:mm').format(draft.date) : '—'),
          _row(context, _t(context, 'Địa điểm', 'Location'), draft.location.isEmpty ? '—' : draft.location),
          _row(context, _t(context, 'Ghi chú', 'Note'), draft.note.isEmpty ? '—' : draft.note),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: onCancel, child: Text(_t(context, 'Hủy', 'Cancel')))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: onConfirm, child: Text(_t(context, 'Lưu giao dịch', 'Save transaction')))),
          ]),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        SizedBox(width: 88, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
