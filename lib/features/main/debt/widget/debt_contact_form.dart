import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'debt_helpers.dart';
import 'debt_phone_field.dart';

class DebtContactEditor extends StatefulWidget {
  final DebtFirebase service;
  final DebtContact? contact;

  const DebtContactEditor({Key? key, required this.service, this.contact})
    : super(key: key);

  @override
  State<DebtContactEditor> createState() => _DebtContactEditorState();
}

class _DebtContactEditorState extends State<DebtContactEditor> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      note = TextEditingController();
  final form = GlobalKey<FormState>();
  String role = 'person';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    name.text = widget.contact?.name ?? '';
    phone.text = widget.contact?.phone ?? '';
    note.text = widget.contact?.note ?? '';
    role = widget.contact?.role ?? 'person';
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      await widget.service.saveContact(
        DebtContact(
          id: widget.contact?.id ?? '',
          name: name.text.trim(),
          phone: phone.text.trim(),
          role: role,
          note: note.text.trim(),
        ),
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (loadingVisible && mounted)
        Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SpendingStyle.background(context),
    appBar: AppBar(
      title: Text(
        widget.contact == null
            ? debtTranslate(context, 'debt_contact_add')
            : debtTranslate(context, 'debt_contact_edit'),
      ),
      backgroundColor: SpendingStyle.background(context),
      actions: [
        SpendingSaveAction(
          label: debtTranslate(
            context,
            widget.contact == null ? 'save' : 'debt_update',
          ),
          onPressed: busy ? null : save,
        ),
      ],
    ),
    body: AbsorbPointer(
      absorbing: busy,
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: name,
              maxLength: 100,
              decoration: SpendingStyle.input(
                context,
                debtTranslate(context, 'debt_contact_name'),
                icon: Icons.person_outline,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? debtTranslate(context, 'debt_contact_name_required')
                  : null,
            ),
            const SizedBox(height: 12),
            DebtPhoneField(controller: phone),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              decoration: SpendingStyle.input(
                context,
                debtTranslate(context, 'debt_contact_role'),
              ),
              items: ['person', 'customer', 'supplier', 'lender', 'borrower']
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(roleName(context, r)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => role = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              maxLength: 500,
              maxLines: 3,
              decoration: SpendingStyle.input(
                context,
                debtTranslate(context, 'debt_note'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}
