import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:flutter/services.dart';
import 'debt_helpers.dart';
import 'debt_loading_skeleton.dart';
import 'debt_category_widgets.dart';
import 'debt_contact_picker.dart';

class DebtEditor extends StatefulWidget {
  final DebtFirebase service;
  final Debt? debt;

  const DebtEditor({super.key, required this.service, this.debt});

  @override
  State<DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends State<DebtEditor> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), note = TextEditingController();
  late DateTime date;
  DateTime? due;
  String direction = 'lend';
  String? contactId;
  bool remind = true,
      busy = false,
      walletTracked = true,
      alreadyInWallet = false;
  late final String draftId;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    date = d?.date ?? DateTime.now();
    draftId = d?.id ?? widget.service.items.doc().id;
    walletTracked = d?.walletTracked ?? true;
    due = d?.dueDate;
    direction = d?.direction ?? 'lend';
    contactId = d?.contactId;
    remind = d?.remind ?? true;
    amount.text = d?.amount.toString() ?? '';
    note.text = d?.note ?? '';
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pick(bool deadline) async {
    final result = await showDatePicker(
      context: context,
      initialDate: (deadline ? due : date) ?? date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null && mounted) {
      setState(() {
        if (deadline) {
          due = result;
        } else {
          date = result;
        }
      });
    }
  }

  Future<void> save(List<DebtContact> list) async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      final selected = list.firstWhere((c) => c.id == contactId);
      final old = widget.debt;
      await widget.service.saveDebt(
        Debt(
          id: draftId,
          contactId: selected.id,
          contactName: selected.name,
          direction: direction,
          amount: int.parse(amount.text),
          date: date,
          dueDate: due,
          remind: remind,
          note: note.text.trim(),
          payments: old?.payments ?? [],
          revision: old?.revision ?? 0,
          walletTracked: walletTracked,
          walletImpact: old?.walletImpact ?? 0,
        ),
        create: old == null,
        alreadyInWallet: alreadyInWallet,
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SpendingStyle.background(context),
    appBar: AppBar(
      backgroundColor: SpendingStyle.background(context),
      title: Text(
        widget.debt == null
            ? debtTranslate(context, 'debt_add')
            : debtTranslate(context, 'debt_edit'),
      ),
      actions: [
        StreamBuilder<List<DebtContact>>(
          stream: widget.service.watchContacts(),
          builder: (context, s) => SpendingSaveAction(
            label: debtTranslate(
              context,
              widget.debt == null ? 'save' : 'debt_update',
            ),
            onPressed: busy || !s.hasData ? null : () => save(s.data!),
          ),
        ),
      ],
    ),
    body: StreamBuilder<List<DebtContact>>(
      stream: widget.service.watchContacts(),
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Text(
              '${debtTranslate(context, 'debt_contacts_load_error')}: ${s.error}',
            ),
          );
        }
        if (!s.hasData) return debtScreenSkeleton(context);
        final list = s.data!;
        final exists = list.any((c) => c.id == contactId);
        return AbsorbPointer(
          absorbing: busy,
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: SpendingStyle.decoration(context),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        DebtTypeSelector(
                          value: direction,
                          onChanged: widget.debt?.payments.isNotEmpty == true
                              ? null
                              : (v) => setState(() => direction = v),
                        ),
                        const SizedBox(height: 18),
                        DebtContactSelectField(
                          service: widget.service,
                          selected: exists
                              ? list.firstWhere((c) => c.id == contactId)
                              : null,
                          enabled: widget.debt?.payments.isNotEmpty != true,
                          onChanged: (c) => setState(() => contactId = c.id),
                        ),
                        TextFormField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          decoration: SpendingStyle.input(
                            context,
                            debtTranslate(context, 'debt_amount'),
                            icon: Icons.payments_outlined,
                          ),
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                              ? debtTranslate(context, 'debt_amount_required')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_month),
                          title: Text(
                            debtTranslate(context, 'debt_transaction_date'),
                          ),
                          subtitle: Text(debtDate(date)),
                          onTap: () => pick(false),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_available),
                          title: Text(debtTranslate(context, 'debt_due_date')),
                          subtitle: Text(
                            due == null
                                ? debtTranslate(context, 'debt_due_not_set')
                                : debtDate(due!),
                          ),
                          onTap: () => pick(true),
                          trailing: due == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => due = null),
                                ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            debtTranslate(context, 'debt_track_wallet'),
                          ),
                          subtitle: Text(
                            widget.debt != null && !widget.debt!.walletTracked
                                ? debtTranslate(
                                    context,
                                    'debt_wallet_enable_hint',
                                  )
                                : debtTranslate(context, 'debt_wallet_hint'),
                          ),
                          value: walletTracked,
                          onChanged: widget.debt?.walletTracked == true
                              ? null
                              : (v) => setState(() => walletTracked = v),
                        ),
                        if (walletTracked && widget.debt?.walletTracked != true)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              debtTranslate(context, 'debt_already_in_wallet'),
                            ),
                            subtitle: Text(
                              debtTranslate(
                                context,
                                'debt_already_in_wallet_hint',
                              ),
                            ),
                            value: alreadyInWallet,
                            onChanged: (v) =>
                                setState(() => alreadyInWallet = v ?? false),
                          ),
                        TextFormField(
                          controller: note,
                          maxLines: 3,
                          maxLength: 500,
                          decoration: SpendingStyle.input(
                            context,
                            debtTranslate(context, 'debt_note'),
                            icon: Icons.edit_note,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    ),
  );
}
