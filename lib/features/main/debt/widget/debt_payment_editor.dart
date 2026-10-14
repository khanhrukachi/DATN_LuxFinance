import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_save_action.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:flutter/services.dart';
import '../widget/debt_helpers.dart';
import '../widget/debt_category_presentation.dart';
import '../widget/debt_category_icon.dart';

class DebtPaymentEditor extends StatefulWidget {
  final Debt debt;
  final DebtFirebase service;

  const DebtPaymentEditor({super.key, required this.debt, required this.service});

  @override
  State<DebtPaymentEditor> createState() => _DebtPaymentEditorState();
}

class _DebtPaymentEditorState extends State<DebtPaymentEditor> {
  final amount = TextEditingController(), note = TextEditingController();
  final form = GlobalKey<FormState>();
  DateTime date = DateTime.now();
  bool saving = false;
  late final String paymentId;

  @override
  void initState() {
    super.initState();
    paymentId = widget.service.items.doc().id;
    if (date.isBefore(widget.debt.date)) date = widget.debt.date;
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      await widget.service.addPayment(
        widget.debt.id,
        DebtPayment(
          id: paymentId,
          amount: int.parse(amount.text),
          date: date,
          note: note.text.trim(),
        ),
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        debtMessage(context, e.toString());
      }
    } finally {
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DebtStyle.background(context),
    appBar: AppBar(
      centerTitle: false,
      titleSpacing: 0,
      leadingWidth: 54,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: FinanceToolbarButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: Icons.arrow_back_rounded,
        onPressed: saving ? null : () => Navigator.maybePop(context),
      ),
      title: Text(
        DebtCategoryPresentation.title(
          context,
          DebtCategoryPresentation.paymentId(widget.debt.direction),
        ),
      ),
      backgroundColor: DebtStyle.background(context),
      actions: [
        DebtSaveAction(
          loading: saving,
          label: debtTranslate(context, 'save'),
          onPressed: saving ? null : save,
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: DebtCategoryIcon(
              id: DebtCategoryPresentation.paymentId(widget.debt.direction),
              size: 64,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${debtTranslate(context, 'debt_remaining')}: ${debtMoney(widget.debt.remaining)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: amount,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            keyboardType: TextInputType.number,
            decoration: DebtStyle.input(
              context,
              debtTranslate(context, 'debt_payment_amount'),
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '') ?? 0;
              return n <= 0 || n > widget.debt.remaining
                  ? '${debtTranslate(context, 'debt_payment_range_error')} ${debtMoney(widget.debt.remaining)}'
                  : null;
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () => setState(
                      () => amount.text = widget.debt.remaining.toString(),
                    ),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(debtTranslate(context, 'debt_pay_all')),
              style: OutlinedButton.styleFrom(
                backgroundColor: DebtStyle.teal.withOpacity(.13),
                side: BorderSide(
                  color: DebtStyle.accent(context).withOpacity(.65),
                ),
                foregroundColor: DebtStyle.accent(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          ListTile(
            title: Text(debtTranslate(context, 'debt_payment_date')),
            subtitle: Text(debtDate(date)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(
                  widget.debt.date.year,
                  widget.debt.date.month,
                  widget.debt.date.day,
                ),
                lastDate: DateTime(2100),
              );
              if (d != null && mounted) setState(() => date = d);
            },
          ),
          TextFormField(
            controller: note,
            maxLength: 500,
            decoration: DebtStyle.input(
              context,
              debtTranslate(context, 'debt_note'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
