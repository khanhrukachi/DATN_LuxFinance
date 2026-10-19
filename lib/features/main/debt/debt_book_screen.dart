import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'widget/debt_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/models/debt.dart';
import 'package:personal_financial_management/features/main/debt/debt_style.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:personal_financial_management/controls/debt_reminder_service.dart';
import 'package:personal_financial_management/controls/wallet_firebase.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'widget/debt_helpers.dart';
import 'widget/debt_screen_skeleton.dart';
import 'widget/debt_category_presentation.dart';
import 'widget/debt_category_icon.dart';
import 'add/add_debt_screen.dart';
import 'debt_detail_screen.dart';
import 'debt_contacts_screen.dart';

export 'debt_detail_screen.dart';
export 'debt_contacts_screen.dart';
export 'add/debt_payment_editor.dart' show DebtPaymentEditor;
export 'widget/debt_editor.dart' show DebtEditor;
export 'widget/debt_contact_editor.dart' show DebtContactEditor;
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
  final TextEditingController searchController = TextEditingController();
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
    searchController.dispose();
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
    if (mounted) debtMessage(context, text);
  }

  void openAddDebt() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddDebtScreen(service: service)),
    );
  }

  void openContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DebtContactsScreen(service: service)),
    );
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
    backgroundColor: DebtStyle.background(context),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      backgroundColor: DebtStyle.background(context),
      titleSpacing: 0,
      leadingWidth: 76,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: FinanceToolbarButton(
        tooltip: debtTranslate(context, 'debt_contacts_title'),
        icon: Icons.people_alt_outlined,
        onPressed: openContacts,
      ),
      title: Text(
        debtTranslate(context, 'debt_book_title'),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        FinanceToolbarButton(
          tooltip: debtTranslate(context, 'debt_add'),
          icon: Icons.add_rounded,
          onPressed: openAddDebt,
        ),
        FinanceToolbarButton(
          tooltip: debtTranslate(context, 'debt_export_csv'),
          icon: Icons.ios_share_rounded,
          loading: exporting,
          onPressed: exporting ? null : export,
        ),
        const SizedBox(width: 14),
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
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: DebtStyle.decoration(context, hero: true),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: DebtStyle.accent(context).withOpacity(.13),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: DebtStyle.accent(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debtTranslate(context, 'debt_wallet_balance'),
                            style: TextStyle(
                              color: DebtStyle.muted(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            w.hasError
                                ? debtTranslate(context, 'debt_wallet_load_error')
                                : w.hasData
                                ? debtMoney(w.data!)
                                : '...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: DebtStyle.text(context),
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              controller: searchController,
              decoration: DebtStyle.input(
                context,
                debtTranslate(context, 'debt_search'),
                icon: Icons.search_rounded,
              ).copyWith(
                suffixIcon: search.isEmpty
                    ? null
                    : FinanceToolbarButton(
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () {
                    searchController.clear();
                    setState(() => search = '');
                  },
                  icon: Icons.close_rounded,
                ),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: DebtStyle.decoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 19, color: DebtStyle.accent(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isEnglish(context) ? 'Filters' : 'Bộ lọc',
                          style: TextStyle(
                            color: DebtStyle.text(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${filtered.length}/${all.length}',
                        style: TextStyle(
                          color: DebtStyle.muted(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in {
                          'all': debtTranslate(context, 'debt_filter_all'),
                          'lend': debtTranslate(context, 'debt_filter_lend'),
                          'borrow': debtTranslate(context, 'debt_filter_borrow'),
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _DebtFilterChip(
                              label: entry.key == 'all'
                                  ? entry.value
                                  : DebtCategoryPresentation.title(
                                context,
                                DebtCategoryPresentation.id(entry.key),
                              ),
                              icon: entry.key == 'all'
                                  ? Icons.all_inclusive_rounded
                                  : entry.key == 'lend'
                                  ? Icons.call_received_rounded
                                  : Icons.call_made_rounded,
                              selected: direction == entry.key,
                              onTap: () => setState(() => direction = entry.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in {
                          'all': debtTranslate(context, 'debt_status_all'),
                          'unpaid': debtTranslate(context, 'debt_status_unpaid'),
                          'partial': debtTranslate(context, 'debt_status_partial'),
                          'paid': debtTranslate(context, 'debt_status_paid'),
                          'overdue': debtTranslate(context, 'debt_status_overdue'),
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _DebtFilterChip(
                              label: entry.value,
                              icon: entry.key == 'all'
                                  ? Icons.filter_list_rounded
                                  : entry.key == 'paid'
                                  ? Icons.check_circle_outline_rounded
                                  : entry.key == 'overdue'
                                  ? Icons.schedule_rounded
                                  : entry.key == 'partial'
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.circle_outlined,
                              selected: status == entry.key,
                              onTap: () => setState(() => status = entry.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (all.isEmpty)
              _DebtEmptyState(onTap: openAddDebt)
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  debtTranslate(context, 'debt_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DebtStyle.muted(context)),
                ),
              ),
            for (final d in filtered)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  decoration: DebtStyle.decoration(context),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                ? DebtStyle.danger
                                : DebtStyle.muted(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: DebtStyle.accent(context)),
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

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');

}

class _DebtFilterChip extends StatelessWidget {
  const _DebtFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = DebtStyle.accent(context);
    return Material(
      color: selected
          ? DebtStyle.teal.withOpacity(DebtStyle.dark(context) ? .22 : .16)
          : DebtStyle.background(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent.withOpacity(.45) : DebtStyle.teal.withOpacity(.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? accent : DebtStyle.muted(context)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? accent : DebtStyle.text(context),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtEmptyState extends StatelessWidget {
  const _DebtEmptyState({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('en');
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          decoration: DebtStyle.decoration(context),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: DebtStyle.teal.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, size: 30, color: DebtStyle.accent(context)),
              ),
              const SizedBox(height: 14),
              Text(
                english ? 'No debt records yet' : 'Chưa có khoản nợ nào',
                style: TextStyle(
                  color: DebtStyle.text(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                english ? 'Tap here to add a debt' : 'Nhấn vào đây để thêm khoản nợ',
                style: TextStyle(
                  color: DebtStyle.accent(context),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Icon(Icons.add_circle_rounded, color: DebtStyle.accent(context), size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

