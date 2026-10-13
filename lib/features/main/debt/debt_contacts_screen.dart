import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'widget/debt_helpers.dart';
import 'widget/debt_loading_skeleton.dart';
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
    backgroundColor: SpendingStyle.background(context),
    appBar: AppBar(
      title: Text(debtTranslate(context, 'debt_contacts_title')),
      backgroundColor: SpendingStyle.background(context),
      actions: [
        IconButton(
          tooltip: debtTranslate(context, 'debt_picker_add'),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          onPressed: () => edit(context, null),
        ),
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
                decoration: SpendingStyle.decoration(context),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: SpendingStyle.teal.withOpacity(.14),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: SpendingStyle.accent(context),
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
                    trailing: IconButton(
                      tooltip: debtTranslate(context, 'common_delete'),
                      icon: const Icon(Icons.delete_outline),
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
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
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
