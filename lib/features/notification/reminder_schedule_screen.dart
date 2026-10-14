import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/notification_service.dart';
import 'package:personal_financial_management/controls/debt_reminder_service.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/features/main/debt/debt_book_screen.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'debt_reminder_settings_screen.dart';
import 'manual_reminder_screen.dart';
import 'utils/reminder_helpers.dart';
import 'widget/reminder_loading_skeleton.dart';
import 'widget/reminder_navigation_button.dart';
import 'widget/reminder_schedule_tile.dart';

export 'manual_reminder_screen.dart';
export 'utils/reminder_helpers.dart' show reminderData;

class ReminderScheduleScreen extends StatefulWidget {
  const ReminderScheduleScreen({super.key});

  @override
  State<ReminderScheduleScreen> createState() => _ReminderScheduleScreenState();
}

class _ReminderScheduleScreenState extends State<ReminderScheduleScreen> {
  final service = NotificationService();
  List<PendingNotificationRequest> items = [];
  String? uid, error;
  bool loading = true, busy = false;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
    load();
  }

  bool get active =>
      uid != null && FirebaseAuth.instance.currentUser?.uid == uid;

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> load() async {
    if (!active) {
      if (mounted) {
        setState(() {
          loading = false;
          error = reminderText(context, 'login_required');
          items = [];
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      await service.initialize();
      final pending = await service.getPendingReminders();
      if (!mounted || !active) return;
      pending.sort((a, b) {
        final x = DateTime.tryParse(
          reminderData(a.payload)['scheduledAt']?.toString() ?? '',
        );
        final y = DateTime.tryParse(
          reminderData(b.payload)['scheduledAt']?.toString() ?? '',
        );
        if (x == null) return y == null ? a.id.compareTo(b.id) : 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
      setState(() {
        items = pending.where((p) {
          final d = reminderData(p.payload);
          return d['uid'] == null || d['uid'] == uid;
        }).toList();
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = reminderText(context, 'load_error');
          loading = false;
        });
      }
    }
  }

  bool daily(PendingNotificationRequest p) =>
      p.id == 2000000001 ||
          reminderData(p.payload)['source'] == 'daily_spending';

  String kind(PendingNotificationRequest p) =>
      reminderData(p.payload)['source'] == 'debt_local'
          ? 'debt'
          : daily(p)
          ? 'daily'
          : 'other';

  Future<void> configureDaily() async {
    if (!active) return;
    PendingNotificationRequest? current;
    for (final item in items) {
      if (daily(item)) {
        current = item;
        break;
      }
    }
    final data = reminderData(current?.payload);
    final initial = TimeOfDay(
      hour: (data['hour'] as num?)?.toInt() ?? 20,
      minute: (data['minute'] as num?)?.toInt() ?? 0,
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected == null || !mounted || !active) return;
    await execute(() async {
      final allowed = await service.requestLocalNotificationPermission();
      if (!allowed) {
        throw StateError(
          reminderText(context, 'permission_enable_in_settings'),
        );
      }
      await service.configureDailyReminder(
        enabled: true,
        hour: selected.hour,
        minute: selected.minute,
      );
    });
  }

  Future<void> execute(Future<void> Function() action) async {
    if (busy || !active) return;
    setState(() => busy = true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      await action();
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
      }
      await load();
    } catch (e) {
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
      }
      message(reminderErrorText(context, e));
    } finally {
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel(PendingNotificationRequest p) async {
    if (busy || !active) return;
    final isDebt = kind(p) == 'debt';
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          reminderText(c, isDebt ? 'disable_debt_title' : 'cancel_title'),
        ),
        content: Text(
          isDebt
              ? reminderText(c, 'disable_debt_message')
              : p.title ?? 'LuxFinance',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(reminderText(c, 'keep')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(reminderText(c, 'cancel')),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || !active) return;
    await execute(() async {
      if (isDebt) {
        final id = reminderData(p.payload)['debtId']?.toString();
        if (id == null || id.isEmpty) {
          throw StateError(reminderText(context, 'missing_debt_id'));
        }
        await DebtFirebase(userId: uid).setReminderEnabled(id, false);
        await DebtReminderService.instance.refreshSafely(uid);
        final err = DebtReminderService.instance.lastError;
        if (err != null) {
          throw StateError(
            reminderText(
              context,
              'debt_sync_failed',
            ).replaceAll('{error}', err),
          );
        }
      } else if (daily(p)) {
        await service.configureDailyReminder(enabled: false);
        if (p.id != 2000000001) await service.cancelReminder(p.id);
      } else {
        await service.cancelReminder(p.id);
      }
    });
  }

  String timing(PendingNotificationRequest p) {
    final data = reminderData(p.payload);
    if (daily(p)) {
      final h = (data['hour'] as num?)?.toInt(),
          m = (data['minute'] as num?)?.toInt();
      return h == null || m == null
          ? reminderText(context, 'daily_time_missing')
          : '${reminderText(context, 'every_day')} ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    final date = DateTime.tryParse(data['scheduledAt']?.toString() ?? '');
    return date == null
        ? reminderText(context, 'schedule_time_missing')
        : DateFormat('dd/MM/yyyy · HH:mm').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = items
        .where((p) => filter == 'all' || kind(p) == filter)
        .toList();
    final canManageDebtReminders = !busy && active;
    return Scaffold(
      backgroundColor: SpendingStyle.background(context),
      appBar: AppBar(
        backgroundColor: SpendingStyle.background(context),
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 48,
        leading: BackButton(color: SpendingStyle.accent(context)),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(reminderText(context, 'schedule_title'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          ReminderToolbarButton(
            tooltip: reminderText(context, 'sync_debt_reminders'),
            onPressed: busy || !active
                ? null
                : () => execute(() async {
              await DebtReminderService.instance.refreshSafely(uid);
              final err = DebtReminderService.instance.lastError;
              if (err != null) throw StateError(err);
            }),
            icon: Icons.sync_rounded,
            loading: busy,
          ),
          ReminderToolbarButton(
            tooltip: reminderText(context, 'add_title'),
            icon: Icons.add_rounded,
            onPressed: busy || !active ? null : () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManualReminderScreen()));
              if (mounted) load();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? reminderLoadingSkeleton(context)
          : error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              TextButton(
                onPressed: load,
                child: Text(reminderText(context, 'try_again')),
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            ReminderInfoPanel(
              icon: Icons.alarm_on_rounded,
              title: reminderText(context, 'pending_count')
                  .replaceAll('{count}', items.length.toString()),
              subtitle: reminderText(context, 'device_schedule_note'),
              hero: true,
            ),
            const SizedBox(height: 14),
            ReminderNavigationButton(
              title: reminderText(context, 'manage_debt_reminders'),
              subtitle: reminderText(context, 'debt_reminders_button_hint'),
              enabled: canManageDebtReminders,
              onTap: !canManageDebtReminders ? null : () async {
                await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const DebtReminderSettingsScreen()));
                if (mounted) load();
              },
            ),
            const SizedBox(height: 12),
            SpendingActionButton(
              label: reminderText(context, 'set_daily_reminder'),
              icon: Icons.schedule_rounded,
              onPressed: busy || !active ? null : configureDaily,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: SpendingStyle.decoration(context),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.tune_rounded, size: 19, color: SpendingStyle.accent(context)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(reminderText(context, 'filter_title'),
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${filtered.length}/${items.length}',
                        style: TextStyle(fontSize: 12, color: SpendingStyle.muted(context))),
                  ]),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final entry in {
                        'all': reminderText(context, 'filter_all'),
                        'debt': reminderText(context, 'filter_debt'),
                        'daily': reminderText(context, 'filter_daily'),
                        'other': reminderText(context, 'filter_other'),
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ReminderFilterChip(
                            label: entry.value,
                            icon: entry.key == 'all' ? Icons.all_inclusive_rounded
                                : entry.key == 'debt' ? Icons.menu_book_rounded
                                : entry.key == 'daily' ? Icons.update_rounded : Icons.alarm_outlined,
                            selected: filter == entry.key,
                            onTap: () => setState(() => filter = entry.key),
                          ),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
            if (filtered.isEmpty) ...[
              const SizedBox(height: 16),
              ReminderInfoPanel(icon: Icons.alarm_off_rounded,
                  title: reminderText(context, 'no_matching_schedules')),
            ],
            for (final p in filtered)
              ReminderScheduleTile(
                notification: p,
                kind: kind(p),
                timing: timing(p),
                onCancel: busy ? null : () => cancel(p),
                onTap: kind(p) == 'debt'
                    ? () {
                  final id = reminderData(
                    p.payload,
                  )['debtId']?.toString();
                  if (id != null && active) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DebtDetailScreen(
                          service: DebtFirebase(userId: uid),
                          id: id,
                        ),
                      ),
                    );
                  }
                }
                    : daily(p)
                    ? configureDaily
                    : reminderData(p.payload)['source'] ==
                    'manual_reminder'
                    ? () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ManualReminderScreen(existing: p),
                    ),
                  );
                  if (mounted) load();
                }
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
