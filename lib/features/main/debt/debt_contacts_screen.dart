import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'widget/debt_helpers.dart';
import 'widget/debt_screen_skeleton.dart';
import 'add/add_debt_contact_screen.dart';
import 'edit/edit_debt_contact_screen.dart';

class DebtContactsScreen extends StatelessWidget {
  final DebtFirebase service;

  const DebtContactsScreen({super.key, required this.service});

  Future<void> edit(BuildContext context, DebtContact? old) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => old == null
            ? AddDebtContactScreen(service: service)
            : EditDebtContactScreen(service: service, contact: old),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DebtStyle.background(context),
    appBar: AppBar(
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 76,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: FinanceToolbarButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: Icons.arrow_back_rounded,
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(debtTranslate(context, 'debt_contacts_title')),
      backgroundColor: DebtStyle.background(context),
      actions: [
        FinanceToolbarButton(
          tooltip: debtTranslate(context, 'debt_picker_add'),
          icon: Icons.person_add_alt_1_rounded,
          onPressed: () => edit(context, null),
        ),
        const SizedBox(width: 14),
      ],
    ),
    body: StreamBuilder<List<DebtContact>>(
      stream: service.watchContacts(),
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Text(
              '${debtTranslate(context, 'debt_contacts_load_error')}: ${s.error}',
            ),
          );
        }
        if (!s.hasData) return debtScreenSkeleton(context);
        if (s.data!.isEmpty) {
          return Center(
            child: Text(debtTranslate(context, 'debt_contact_empty')),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            for (final c in s.data!)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: DebtStyle.decoration(context),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: DebtStyle.teal.withOpacity(.14),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: DebtStyle.accent(context),
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${roleName(context, c.role)}${c.phone.isEmpty ? '' : ' · ${c.phone}'}${c.note.isEmpty ? '' : '\n${c.note}'}',
                    ),
                    isThreeLine: c.note.isNotEmpty,
                    onTap: () => edit(context, c),
                    trailing: FinanceToolbarButton(
                      tooltip: debtTranslate(context, 'common_delete'),
                      icon: Icons.delete_outline_rounded,
                      color: DebtStyle.danger,
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              debtTranslate(
                                context,
                                'debt_contact_delete_title',
                              ),
                            ),
                            content: Text(c.name),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  debtTranslate(context, 'common_cancel'),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  debtTranslate(context, 'common_delete'),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (yes != true) return;
                        loadingAnimation(context);
                        var loadingVisible = true;
                        try {
                          await service.deleteContact(c.id);
                        } catch (e) {
                          if (loadingVisible) {
                            Navigator.of(context, rootNavigator: true).pop();
                            loadingVisible = false;
                          }
                          debtMessage(context, e.toString());
                        } finally {
                          if (loadingVisible) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
