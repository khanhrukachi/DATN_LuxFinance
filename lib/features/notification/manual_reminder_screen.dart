import 'widget/reminder_navigation_button.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/notification_service.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'utils/reminder_helpers.dart';

class ManualReminderScreen extends StatefulWidget {
  final PendingNotificationRequest? existing;

  const ManualReminderScreen({super.key, this.existing});

  @override
  State<ManualReminderScreen> createState() => _ManualReminderScreenState();
}

class _ManualReminderScreenState extends State<ManualReminderScreen> {
  final title = TextEditingController(), body = TextEditingController();
  final form = GlobalKey<FormState>();
  final service = NotificationService();
  DateTime time = DateTime.now().add(const Duration(hours: 1));
  bool saving = false;
  int? id;
  late final String? uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
    final old = widget.existing;
    if (old != null) {
      id = old.id;
      title.text = old.title ?? '';
      body.text = old.body ?? '';
      time =
          DateTime.tryParse(
            reminderData(old.payload)['scheduledAt']?.toString() ?? '',
          )?.toLocal() ??
              time;
    }
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final date = await showDatePicker(
      context: context,
      initialDate: time,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final hour = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(time),
    );
    if (hour != null && mounted) {
      setState(
            () => time = DateTime(
          date.year,
          date.month,
          date.day,
          hour.hour,
          hour.minute,
        ),
      );
    }
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    if (!time.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reminderText(context, 'choose_future_time'))),
      );
      return;
    }
    setState(() => saving = true);
    loadingAnimation(context);
    var loadingVisible = true;
    try {
      if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError(reminderText(context, 'session_changed'));
      }
      final allowed = await service.requestLocalNotificationPermission();
      if (!allowed) {
        throw StateError(reminderText(context, 'permission_denied'));
      }
      final pending = await service.getPendingReminders();
      if (id == null && pending.length >= 60) {
        throw StateError(reminderText(context, 'schedule_limit_reached'));
      }
      if (id == null) {
        final used = pending.map((p) => p.id).toSet();
        var candidate =
            1400000000 + DateTime.now().millisecondsSinceEpoch % 100000000;
        while (used.contains(candidate)) {
          candidate++;
        }
        id = candidate;
      }
      await service.scheduleReminder(
        id: id!,
        scheduledAt: time,
        title: title.text.trim(),
        body: body.text.trim(),
        data: {'source': 'manual_reminder', 'uid': uid},
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingVisible = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reminderErrorText(context, e))));
      }
    } finally {
      if (loadingVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
      title: Text(
        reminderText(
          context,
          widget.existing == null ? 'add_title' : 'edit_title',
        ),
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    body: AbsorbPointer(
      absorbing: saving,
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: SpendingStyle.decoration(context),
              child: Column(children: [
                TextFormField(
                  controller: title,
                  maxLength: 100,
                  decoration: SpendingStyle.input(
                    context,
                    reminderText(context, 'title_field'),
                    icon: Icons.notifications_outlined,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? reminderText(context, 'title_required')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: body,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: SpendingStyle.input(
                    context,
                    reminderText(context, 'message_field'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: SpendingStyle.decoration(context),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: SpendingFieldIcon(icon: Icons.event_available_rounded),
                  trailing: Icon(Icons.edit_calendar_rounded, color: SpendingStyle.accent(context)),
                  title: Text(reminderText(context, 'schedule_time')),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat('dd/MM/yyyy · HH:mm').format(time),
                          style: TextStyle(fontWeight: FontWeight.w600, color: SpendingStyle.accent(context)))),
                  onTap: pick,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SpendingActionButton(
              label: reminderText(context, 'save_schedule'),
              icon: Icons.check_rounded,
              onPressed: saving ? null : save,
            ),
          ],
        ),
      ),
    ),
  );
}
