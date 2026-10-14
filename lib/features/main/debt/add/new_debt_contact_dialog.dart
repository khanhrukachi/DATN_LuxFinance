import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_action_button.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import '../widget/debt_helpers.dart';
import '../widget/debt_phone_field.dart';

class NewDebtContactDialog extends StatefulWidget {
  final DebtFirebase service;

  const NewDebtContactDialog({super.key, required this.service});

  @override
  State<NewDebtContactDialog> createState() => _NewDebtContactDialogState();
}

class _NewDebtContactDialogState extends State<NewDebtContactDialog> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      note = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  late final String id;
  String role = 'person';

  @override
  void initState() {
    super.initState();
    id = widget.service.contacts.doc().id;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      final c = DebtContact(
        id: id,
        name: name.text.trim(),
        phone: phone.text.trim(),
        role: role,
        note: note.text.trim(),
      );
      await widget.service.saveContact(c);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
        Navigator.pop(context, c);
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
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Dialog(
      backgroundColor: DebtStyle.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: form,
            child: AbsorbPointer(
              absorbing: saving,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          debtTranslate(context, 'debt_contact_new_title'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FinanceToolbarButton(
                        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                        onPressed: saving ? null : () => Navigator.pop(context),
                        icon: Icons.close_rounded,
                      ),
                    ],
                  ),
                  Text(
                    debtTranslate(context, 'debt_contact_new_hint'),
                    style: TextStyle(
                      fontSize: 13,
                      color: DebtStyle.muted(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: name,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: DebtStyle.input(
                      context,
                      debtTranslate(context, 'debt_contact_name'),
                      icon: Icons.person_outline,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? debtTranslate(context, 'debt_contact_name_required')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DebtPhoneField(controller: phone),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: DebtStyle.input(
                      context,
                      debtTranslate(context, 'debt_contact_role'),
                      icon: Icons.badge_outlined,
                    ),
                    items:
                    ['person', 'customer', 'supplier', 'lender', 'borrower']
                        .map(
                          (r) => DropdownMenuItem(
                        value: r,
                        child: Text(roleName(context, r)),
                      ),
                    )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) {
                      if (v != null) setState(() => role = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: note,
                    maxLength: 500,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: DebtStyle.input(
                      context,
                      debtTranslate(context, 'debt_contact_note_optional'),
                      icon: Icons.notes_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DebtActionButton(
                    label: debtTranslate(
                      context,
                      'debt_contact_save_and_select',
                    ),
                    icon: Icons.check_rounded,
                    onPressed: saving ? null : save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
