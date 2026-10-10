import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/core/constants/list.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'main_style.dart';

class TransactionInputForm extends StatefulWidget {
  const TransactionInputForm({Key? key, required this.expense, required this.categories}) : super(key: key);
  final bool expense;
  final List<dynamic> categories;
  @override
  State<TransactionInputForm> createState() => _TransactionInputFormState();
}

class _TransactionInputFormState extends State<TransactionInputForm> {
  final _formKey = GlobalKey<FormState>();
  final _money = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  int _selected = 0;
  bool _saving = false;
  String tr(String key) => AppLocalizations.of(context).translate(key);
  @override
  void dispose() { _money.dispose(); _note.dispose(); super.dispose(); }
  Future<void> _pickDate() async {
    final result = await showDatePicker(context: context, initialDate: _date,
      firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (mounted && result != null) setState(() => _date = DateTime(
      result.year, result.month, result.day, _date.hour, _date.minute));
  }
  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate() || widget.categories.isEmpty) return;
    final amount = int.tryParse(_money.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) return;
    setState(() => _saving = true);
    try {
      final key = '${widget.categories[_selected]['name'] ?? ''}';
      final canonicalType = listType.indexWhere((item) => item['title'] == key);
      await SpendingFirebase.addSpending(Spending(
        money: widget.expense ? -amount : amount, note: _note.text.trim(),
        type: canonicalType >= 0 ? canonicalType : _selected, dateTime: _date));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('main_save_error'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) => Form(key: _formKey,
    child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(color: MainStyle.card(context), clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: MainStyle.teal.withOpacity(.16))),
          child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
            Material(color: MainStyle.background(context), borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: _saving ? null : _pickDate,
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  Icon(Icons.calendar_month_outlined, color: MainStyle.accent(context), size: 20),
                  const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr(widget.expense ? 'spending_date' : 'income_date'),
                      style: TextStyle(fontSize: 12, color: MainStyle.muted(context))),
                    const SizedBox(height: 4), Text(DateFormat('dd/MM/yyyy').format(_date),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MainStyle.text(context))),
                  ])), Icon(Icons.expand_more_rounded, color: MainStyle.accent(context)),
                ])))),
            const SizedBox(height: 14),
            TextFormField(controller: _money, enabled: !_saving, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                CurrencyTextInputFormatter(NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0))],
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                color: widget.expense ? MainStyle.danger : MainStyle.accent(context)),
              decoration: MainStyle.input(context, tr(widget.expense ? 'expense' : 'income'), Icons.payments_outlined)
                .copyWith(suffixText: '₫'),
              validator: (value) => (int.tryParse((value ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) <= 0
                ? tr('please_enter_the_amount') : null),
            const SizedBox(height: 14),
            TextFormField(controller: _note, enabled: !_saving, minLines: 1, maxLines: 3,
              style: TextStyle(fontSize: 14, color: MainStyle.text(context)),
              decoration: MainStyle.input(context, tr('note'), Icons.notes_rounded).copyWith(hintText: tr('more_details'))),
          ]))),
        const SizedBox(height: 22),
        Text(tr('category'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MainStyle.text(context))),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (int index = 0; index < widget.categories.length; index++)
            _category(index),
        ]),
        const SizedBox(height: 24),
        Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias,
          child: Ink(decoration: const BoxDecoration(gradient: MainStyle.gradient),
            child: TextButton(onPressed: _saving || widget.categories.isEmpty ? null : _save,
              style: TextButton.styleFrom(foregroundColor: MainStyle.ink,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_saving) ...[const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: MainStyle.ink)), const SizedBox(width: 10)],
                Flexible(child: Text(tr(_saving ? 'main_saving' : 'save'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              ])))),
      ])),
  );
  Widget _category(int index) {
    final selected = index == _selected;
    final category = widget.categories[index];
    final String? image = category['icon'] is String ? category['icon'] as String : null;
    return SizedBox(width: 104, child: Semantics(selected: selected, button: true,
      child: Material(color: selected ? MainStyle.accent(context).withOpacity(.12) : MainStyle.card(context),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? MainStyle.accent(context) : MainStyle.teal.withOpacity(.16))),
        child: InkWell(onTap: _saving ? null : () => setState(() => _selected = index),
          child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            SizedBox(width: 32, height: 32, child: image == null
              ? Icon(Icons.label_outline_rounded, color: MainStyle.accent(context))
              : Image.asset(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) =>
                Icon(Icons.label_outline_rounded, color: MainStyle.accent(context)))),
            const SizedBox(height: 8), Text(tr('${category['name'] ?? 'other'}'), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: MainStyle.text(context))),
          ]))),
    )));
  }
}
