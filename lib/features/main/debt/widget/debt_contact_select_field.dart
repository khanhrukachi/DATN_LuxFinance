import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'debt_helpers.dart';
import 'debt_contact_picker.dart';
import 'debt_contact_avatar.dart';

class DebtContactSelectField extends StatelessWidget {
  final DebtFirebase service;
  final DebtContact? selected;
  final bool enabled;
  final ValueChanged<DebtContact> onChanged;

  const DebtContactSelectField({
    Key? key,
    required this.service,
    this.selected,
    required this.enabled,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => FormField<String>(
    key: ValueKey(selected?.id),
    initialValue: selected?.id,
    validator: (v) => v == null || v.isEmpty
        ? debtTranslate(context, 'debt_contact_required')
        : null,
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          debtTranslate(context, 'debt_contact'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Material(
          color: DebtStyle.background(context),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: !enabled
                ? null
                : () async {
                    FocusScope.of(context).unfocus();
                    final contact = await showModalBottomSheet<DebtContact>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: DebtStyle.card(context),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      builder: (ctx) {
                        final media = MediaQuery.of(ctx);
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: media.viewInsets.bottom,
                          ),
                          child: SizedBox(
                            height:
                                (media.size.height - media.viewInsets.bottom) *
                                .8,
                            child: DebtContactPicker(
                              service: service,
                              selectedId: selected?.id,
                            ),
                          ),
                        );
                      },
                    );
                    if (contact == null) return;
                    if (!field.mounted) return;
                    field.didChange(contact.id);
                    onChanged(contact);
                  },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: field.hasError
                      ? DebtStyle.danger
                      : DebtStyle.teal.withOpacity(.2),
                ),
              ),
              child: Row(
                children: [
                  DebtContactAvatar(
                    name: selected?.name ?? '',
                    selected: selected != null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected?.name ??
                              debtTranslate(
                                context,
                                'debt_select_or_add_person',
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selected == null
                              ? debtTranslate(context, 'debt_name_and_phone')
                              : selected!.phone.isEmpty
                              ? debtTranslate(context, 'debt_selected_contact')
                              : selected!.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: DebtStyle.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    enabled
                        ? Icons.expand_more_rounded
                        : Icons.lock_outline_rounded,
                    color: DebtStyle.accent(context),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 7, left: 4),
            child: Text(
              field.errorText!,
              style: const TextStyle(color: DebtStyle.danger, fontSize: 12),
            ),
          ),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              debtTranslate(context, 'debt_contact_locked'),
              style: TextStyle(
                fontSize: 12,
                color: DebtStyle.muted(context),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
