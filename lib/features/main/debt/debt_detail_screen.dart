import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_action_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'widget/debt_helpers.dart';
import 'widget/debt_screen_skeleton.dart';
import 'widget/debt_category_presentation.dart';
import 'widget/debt_category_icon.dart';
import 'widget/debt_detail_actions.dart';
import 'add/debt_payment_editor.dart';
import 'edit/edit_debt_screen.dart';

class DebtDetailScreen extends StatefulWidget {
  final DebtFirebase service;
  final String id;

  const DebtDetailScreen({super.key, required this.service, required this.id});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  bool busy = false;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> stream;

  @override
  void initState() {
    super.initState();
    stream = widget.service.items.doc(widget.id).snapshots();
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: DebtStyle.card(c),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(
            Icons.info_outline_rounded,
            color: DebtStyle.danger,
            size: 30,
          ),
          title: Text(debtTranslate(context, 'debt_confirm_title')),
          content: SingleChildScrollView(child: Text(text)),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(c, false),
              child: Text(debtTranslate(context, 'common_cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: DebtStyle.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(c, true),
              child: Text(debtTranslate(context, 'common_confirm')),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> run(Future<void> Function() action) async {
    setState(() => busy = true);
    loadingAnimation(context);
    var loadingVisible = true;
    var succeeded = false;
    try {
      await action();
      succeeded = true;
    } catch (e) {
      if (mounted) {
        debtMessage(context, e.toString());
      }
    } finally {
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => busy = false);
    }
    return succeeded;
  }

  Future<void> payment(Debt d) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DebtPaymentEditor(debt: d, service: widget.service),
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
      backgroundColor: DebtStyle.background(context),
      title: Text(
        debtTranslate(context, 'debt_detail'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Text(
              '${debtTranslate(context, 'debt_detail_load_error')}: ${s.error}',
            ),
          );
        }
        if (!s.hasData) return debtScreenSkeleton(context);
        if (!s.data!.exists) {
          return Center(child: Text(debtTranslate(context, 'debt_deleted')));
        }
        final d = Debt.fromDoc(s.data!);
        return AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: DebtStyle.decoration(context, hero: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DebtCategoryIcon(
                          id: DebtCategoryPresentation.id(d.direction),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.contactName,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DebtCategoryPresentation.title(
                                  context,
                                  DebtCategoryPresentation.id(d.direction),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${d.direction == 'lend' ? debtTranslate(context, 'debt_to_collect') : debtTranslate(context, 'debt_to_pay')}: ${debtMoney(d.remaining)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${debtTranslate(context, 'debt_original')}: ${debtMoney(d.amount)}\n${debtTranslate(context, 'debt_paid')}: ${debtMoney(d.paid)}\n${debtTranslate(context, 'debt_date')}: ${debtDate(d.date)}\n${debtTranslate(context, 'debt_due_date')}: ${d.dueDate == null ? debtTranslate(context, 'debt_due_not_set') : debtDate(d.dueDate!)}\n${debtStatus(context, d)}',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      d.walletTracked
                          ? debtTranslate(context, 'debt_wallet_linked')
                          : debtTranslate(context, 'debt_wallet_not_linked'),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: d.paid / d.amount,
                      color: DebtStyle.accent(context),
                    ),
                    if (d.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(d.note),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (d.remaining > 0)
                DebtActionButton(
                  label: DebtCategoryPresentation.title(
                    context,
                    DebtCategoryPresentation.paymentId(d.direction),
                  ),
                  icon: Icons.payments_outlined,
                  onPressed: busy ? null : () => payment(d),
                ),
              DebtDetailActions(
                onEdit: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditDebtScreen(service: widget.service, debt: d),
                  ),
                ),
                onDelete: () async {
                  if (await confirm(
                    debtTranslate(context, 'debt_delete_confirm'),
                  )) {
                    final deleted = await run(
                      () => widget.service.deleteDebt(d),
                    );
                    if (deleted && mounted) Navigator.pop(context);
                  }
                },
              ),
              Text(
                debtTranslate(context, 'debt_payment_history'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (d.payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(debtTranslate(context, 'debt_no_payments')),
                ),
              for (final p in d.payments.reversed)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  decoration: DebtStyle.decoration(context),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: DebtCategoryIcon(
                        id: DebtCategoryPresentation.paymentId(d.direction),
                      ),
                      title: Text(debtMoney(p.amount)),
                      subtitle: Text(
                        '${debtDate(p.date)}${p.note.isEmpty ? '' : '\n${p.note}'}',
                      ),
                      trailing: FinanceToolbarButton(
                        tooltip: debtTranslate(context, 'debt_undo_payment'),
                        icon: Icons.undo_rounded,
                        onPressed: () async {
                          if (await confirm(
                            debtTranslate(context, 'debt_undo_confirm'),
                          )) {
                            await run(
                              () => widget.service.removePayment(d.id, p.id),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
