import 'widget/debt_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:personal_financial_management/controls/debt_reminder_service.dart';
import 'package:personal_financial_management/controls/wallet_firebase.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'widget/debt_helpers.dart';
import 'widget/debt_loading_skeleton.dart';
import 'widget/debt_category_widgets.dart';
import 'add/add_debt_screen.dart';
import 'debt_detail_screen.dart';
import 'debt_contacts_screen.dart';

export 'debt_detail_screen.dart';
export 'debt_contacts_screen.dart';
export 'add/add_debt_payment_screen.dart';
export 'widget/debt_form.dart' show DebtEditor;
export 'widget/debt_contact_form.dart' show DebtContactEditor;
export 'widget/debt_helpers.dart'
    show debtMoney, debtDate, debtStatus, roleName;
export 'add/add_debt_screen.dart';
export 'add/add_debt_contact_screen.dart';
export 'edit/edit_debt_screen.dart';
export 'edit/edit_debt_contact_screen.dart';

class DebtBookScreen extends StatefulWidget {
  const DebtBookScreen({super.key});

  @override
  State<DebtBookScreen> createState() => _DebtBookScreenState();
}

class _DebtBookScreenState extends State<DebtBookScreen>
    with WidgetsBindingObserver {
  late final DebtFirebase service;
  late final Stream<List<Debt>> debts;
  late final Stream<List<DebtContact>> contacts;
  late final Stream<int> balance;
  String search = '', direction = 'all', status = 'all';
  bool exporting = false, checking = false;
  List<Debt> latest = [];

  @override
  void initState() {
    super.initState();
    service = DebtFirebase();
    debts = service.watchDebts();
    contacts = service.watchContacts();
    balance = WalletFirebase.watch(service.uid);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => checkReminders());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkReminders();
  }

  Future<void> checkReminders() async {
    if (checking) return;
    checking = true;
    try {
      await DebtReminderService.instance.refreshSafely(service.uid);
      final error = DebtReminderService.instance.lastError;
      if (error != null && mounted) {
        message('${debtTranslate(context, 'debt_reminder_error')}: $error');
      }
    } catch (e) {
      if (mounted) {
        message('${debtTranslate(context, 'debt_reminder_check_error')}: $e');
      }
    } finally {
      checking = false;
    }
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> export() async {
    setState(() => exporting = true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      final snapshot = await service.items.get();
      final all = snapshot.docs.map(Debt.fromDoc).toList();
      if (!mounted) return;
      String cell(Object? s) {
        var value = s?.toString() ?? '';
        if (RegExp(r'^[=+@\-\t\r]').hasMatch(value)) value = "'$value";
        return '"${value.replaceAll('"', '""')}"';
      }

      final rows = <List<Object?>>[
        [
          debtTranslate(context, 'debt_export_record_type'),
          debtTranslate(context, 'debt_export_id'),
          debtTranslate(context, 'debt_export_contact'),
          debtTranslate(context, 'debt_export_category'),
          debtTranslate(context, 'debt_export_amount'),
          debtTranslate(context, 'debt_export_paid'),
          debtTranslate(context, 'debt_export_remaining'),
          debtTranslate(context, 'debt_export_date'),
          debtTranslate(context, 'debt_export_due_date'),
          debtTranslate(context, 'debt_export_status'),
          debtTranslate(context, 'debt_export_note'),
        ],
        for (final d in all) ...[
          [
            debtTranslate(context, 'debt_export_debt'),
            d.id,
            d.contactName,
            DebtCategoryPresentation.title(context, d.categoryId),
            d.amount,
            d.paid,
            d.remaining,
            debtDate(d.date),
            d.dueDate == null ? '' : debtDate(d.dueDate!),
            debtStatus(context, d),
            d.note,
          ],
          for (final p in d.payments)
            [
              debtTranslate(context, 'debt_export_payment'),
              d.id,
              d.contactName,
              DebtCategoryPresentation.title(context, d.paymentCategoryId),
              p.amount,
              '',
              '',
              debtDate(p.date),
              '',
              '',
              p.note,
            ],
        ],
      ];
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/so_no_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsBytes([
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(rows.map((r) => r.map(cell).join(',')).join('\r\n')),
      ]);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      loadingVisible = false;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: debtTranslate(context, 'debt_export_share_title'),
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      message('${debtTranslate(context, 'debt_export_error')}: $e');
    } finally {
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SpendingStyle.background(context),
    appBar: AppBar(
      backgroundColor: SpendingStyle.background(context),
      title: Text(debtTranslate(context, 'debt_book_title')),
      actions: [
        IconButton(
          tooltip: debtTranslate(context, 'debt_add'),
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddDebtScreen(service: service)),
          ),
        ),
        IconButton(
          tooltip: debtTranslate(context, 'debt_contacts_title'),
          icon: const Icon(Icons.people_outline),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DebtContactsScreen(service: service),
            ),
          ),
        ),
        IconButton(
          tooltip: debtTranslate(context, 'debt_export_csv'),
          icon: const Icon(Icons.ios_share),
          onPressed: exporting ? null : export,
        ),
      ],
    ),
    body: StreamBuilder<List<Debt>>(
      stream: debts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${debtTranslate(context, 'debt_load_error')}: ${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData) return debtScreenSkeleton(context);
        final all = snapshot.data!;
        latest = all;
        final filtered = all
            .where(
              (d) =>
                  (direction == 'all' || d.direction == direction) &&
                  (status == 'all' ||
                      (status == 'overdue' ? d.overdue : d.status == status)) &&
                  '${d.contactName} ${d.note}'.toLowerCase().contains(
                    search.toLowerCase(),
                  ),
            )
            .toList();
        int total(String type) => all
            .where((d) => d.direction == type)
            .fold(0, (s, d) => s + d.remaining);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            StreamBuilder<int>(
              stream: balance,
              builder: (context, w) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: SpendingStyle.decoration(context),
                child: Text(
                  w.hasError
                      ? debtTranslate(context, 'debt_wallet_load_error')
                      : '${debtTranslate(context, 'debt_wallet_balance')}: ${w.hasData ? debtMoney(w.data!) : '...'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            DebtSummaryCard(
              toCollect: total('lend'),
              toPay: total('borrow'),
              overdueCount: all.where((d) => d.overdue).length,
              completedCount: all.where((d) => d.status == 'paid').length,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: SpendingStyle.input(
                context,
                debtTranslate(context, 'debt_search'),
                icon: Icons.search,
              ),
              onChanged: (v) => setState(() => search = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in {
                  'all': debtTranslate(context, 'debt_filter_all'),
                  'lend': debtTranslate(context, 'debt_filter_lend'),
                  'borrow': debtTranslate(context, 'debt_filter_borrow'),
                }.entries)
                  ChoiceChip(
                    avatar: entry.key == 'all'
                        ? null
                        : DebtCategoryIcon(
                            id: DebtCategoryPresentation.id(entry.key),
                            size: 24,
                          ),
                    label: Text(
                      entry.key == 'all'
                          ? entry.value
                          : DebtCategoryPresentation.title(
                              context,
                              DebtCategoryPresentation.id(entry.key),
                            ),
                    ),
                    selected: direction == entry.key,
                    onSelected: (_) => setState(() => direction = entry.key),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in {
                  'all': debtTranslate(context, 'debt_status_all'),
                  'unpaid': debtTranslate(context, 'debt_status_unpaid'),
                  'partial': debtTranslate(context, 'debt_status_partial'),
                  'paid': debtTranslate(context, 'debt_status_paid'),
                  'overdue': debtTranslate(context, 'debt_status_overdue'),
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: status == entry.key,
                    onSelected: (_) => setState(() => status = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${filtered.length} ${debtTranslate(context, filtered.length == 1 ? 'debt_count_one' : 'debt_count_many')}',
            ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  debtTranslate(context, 'debt_empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final d in filtered)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  decoration: SpendingStyle.decoration(context),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: DebtCategoryIcon(
                        id: DebtCategoryPresentation.id(d.direction),
                      ),
                      title: Text(
                        d.contactName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${d.direction == 'lend' ? debtTranslate(context, 'debt_to_collect') : debtTranslate(context, 'debt_to_pay')}: ${debtMoney(d.remaining)}\n${debtStatus(context, d)}${d.dueDate == null ? '' : ' · ${debtTranslate(context, 'debt_due_date')} ${debtDate(d.dueDate!)}'}',
                          style: TextStyle(
                            color: d.overdue
                                ? SpendingStyle.danger
                                : SpendingStyle.muted(context),
                          ),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DebtDetailScreen(service: service, id: d.id),
                        ),
                      ),
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
