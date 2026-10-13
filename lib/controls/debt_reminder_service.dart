import 'package:personal_financial_management/setting/localization/service_localizations.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../models/debt.dart';
import 'notification_service.dart';

/// Local schedules: no Python, HTTP service, Cloud Function or cron required.
/// Reuses NotificationService initialization, preserving its tap callbacks.
/// Uses the existing NotificationService scheduling API.
class DebtReminderService {
  DebtReminderService._();

  static final instance = DebtReminderService._();
  final notificationService = NotificationService();
  Future<void> _queue = Future.value();
  String? lastError;
  bool _zonesReady = false;

  Future<void> _initialize() async {
    await NotificationService().initialize().timeout(
      const Duration(seconds: 10),
    );
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
  }

  Future<bool> requestPermission() =>
      notificationService.requestLocalNotificationPermission();

  Future<void> refreshSafely(String? uid) {
    _queue = _queue.then((_) async {
      try {
        await _refresh(uid);
        lastError = null;
      } catch (e) {
        lastError = ServiceLocalizations.errorText(e);
        debugPrint('Sổ nợ đã lưu; chưa đồng bộ được nhắc hạn: $e');
      }
    });
    return _queue;
  }

  bool _isDebt(String? payload) {
    try {
      return (jsonDecode(payload ?? '') as Map)['source'] == 'debt_local';
    } catch (_) {
      return false;
    }
  }

  Future<void> _refresh(String? uid) async {
    await ServiceLocalizations.initialize();
    await _initialize();
    final prefs = await SharedPreferences.getInstance();
    final pending = await notificationService.getPendingReminders();
    final previous = prefs.getStringList('lux_debt_local_ids') ?? [];
    final owned = pending
        .where((p) => _isDebt(p.payload))
        .map((p) => p.id)
        .toSet();
    for (final s in previous) {
      final n = int.tryParse(s);
      if (n != null) owned.add(n);
    }
    if (uid != null && FirebaseAuth.instance.currentUser?.uid != uid) return;
    // Fetch before cancellation so network failures preserve existing alarms.
    final docs = uid == null
        ? null
        : await FirebaseFirestore.instance
              .collection('debt_books')
              .doc(uid)
              .collection('items')
              .get()
              .timeout(const Duration(seconds: 10));
    if (uid != null && FirebaseAuth.instance.currentUser?.uid != uid) return;
    // Cancel only this feature's alarms; retain 20h and budget notifications.
    for (final id in owned) {
      await notificationService.cancelReminder(id);
    }
    await prefs.setStringList('lux_debt_local_ids', []);
    if (uid == null || docs == null) return;
    final location = tz.getLocation('Asia/Ho_Chi_Minh');
    final now = tz.TZDateTime.now(location);
    final today = tz.TZDateTime(location, now.year, now.month, now.day);
    final schedules = <_DebtAlarm>[];
    final notification = NotificationService();
    for (final doc in docs.docs) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      final d = Debt.fromDoc(doc);
      if (!d.remind || d.remaining <= 0 || d.dueDate == null) continue;
      final raw = d.dueDate!;
      var first = tz.TZDateTime(location, raw.year, raw.month, raw.day, 9);
      // Already due: next local 9am. Do not show an old alarm immediately.
      if (!first.isAfter(now)) {
        first = tz.TZDateTime(location, now.year, now.month, now.day, 9);
        if (!first.isAfter(now)) {
          first = tz.TZDateTime(location, now.year, now.month, now.day + 1, 9);
        }
      }
      for (final days in [0, 1, 7]) {
        schedules.add(
          _DebtAlarm(
            d,
            tz.TZDateTime(
              location,
              first.year,
              first.month,
              first.day + days,
              9,
            ),
          ),
        );
      }
      final dueDay = tz.TZDateTime(location, raw.year, raw.month, raw.day);
      if (!dueDay.isAfter(today)) {
        await notification.createNotification(
          title: ServiceLocalizations.text(
            dueDay.isBefore(today)
                ? 'service_debt_overdue_title'
                : 'service_debt_due_title',
          ),
          body: ServiceLocalizations.text(
            'service_debt_due_body',
            args: {
              'name': d.contactName,
              'action': ServiceLocalizations.text(
                d.direction == 'lend'
                    ? 'service_debt_collect'
                    : 'service_debt_pay',
              ),
              'amount':
                  '${NumberFormat.decimalPattern(ServiceLocalizations.numberLocale).format(d.remaining)} ₫',
            },
          ),
          type: dueDay.isBefore(today) ? 'danger' : 'warning',
          deduplicationKey:
              'debt_${d.id}_${DateFormat('yyyyMMdd').format(now)}',
          showLocal: false,
          data: {
            'source': 'debt',
            'language': ServiceLocalizations.language,
            'debtId': d.id,
            'direction': d.direction,
            'categoryId': d.direction == 'borrow' ? 'borrow' : 'loan',
          },
        );
      }
    }
    schedules.sort((a, b) => a.when.compareTo(b.when));
    final others = pending
        .where((p) => !_isDebt(p.payload) && !owned.contains(p.id))
        .toList();
    final capacity = (60 - others.length).clamp(0, 30).toInt();
    final used = others.map((p) => p.id).toSet();
    final saved = <String>[];
    var id = 1700000000;
    for (final alarm in schedules.take(capacity)) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) break;
      while (used.contains(id)) {
        id++;
      }
      // Save ownership before scheduling: a failed call remains cancellable.
      saved.add(id.toString());
      await prefs.setStringList('lux_debt_local_ids', saved);
      await notificationService.scheduleReminder(
        id: id,
        scheduledAt: alarm.when,
        title: ServiceLocalizations.text('service_debt_alarm_title'),
        body: ServiceLocalizations.text(
          'service_debt_alarm_body',
          args: {
            'name': alarm.debt.contactName,
            'date': DateFormat(
              ServiceLocalizations.language == 'en'
                  ? 'MM/dd/yyyy'
                  : 'dd/MM/yyyy',
            ).format(alarm.debt.dueDate!),
            'action': ServiceLocalizations.text(
              alarm.debt.direction == 'lend'
                  ? 'service_debt_collect_short'
                  : 'service_debt_pay_short',
            ),
          },
        ),
        data: {
          'source': 'debt_local',
          'language': ServiceLocalizations.language,
          'uid': uid,
          'debtId': alarm.debt.id,
          'direction': alarm.debt.direction,
          'categoryId': alarm.debt.direction == 'borrow' ? 'borrow' : 'loan',
        },
      );
      used.add(id);
      id++;
    }
  }
}

class _DebtAlarm {
  final Debt debt;
  final tz.TZDateTime when;

  _DebtAlarm(this.debt, this.when);
}
