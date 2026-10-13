import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/controls/debt_reminder_service.dart';
import 'package:personal_financial_management/controls/notification_service.dart';
import 'package:personal_financial_management/features/notification/notification_screen.dart';

import '../debt_book_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Wrap MaterialApp.builder once after Firebase initialization.
/// Cancels debt reminders on sign-out/account switch; updates on remote edits.
final luxFinanceNavigatorKey = GlobalKey<NavigatorState>();

class DebtSyncScope extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  const DebtSyncScope({Key? key, required this.child, this.navigatorKey})
    : super(key: key);

  @override
  State<DebtSyncScope> createState() => _DebtSyncScopeState();
}

class _DebtSyncScopeState extends State<DebtSyncScope>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? auth;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? debts;
  String? uid;
  int generation = 0;
  void Function(Map<String, dynamic>)? previousTap;
  late final void Function(Map<String, dynamic>) tapHandler;

  void _tap(Map<String, dynamic> data) {
    final source = data['source'];
    if (![
      'debt',
      'debt_local',
      'manual_reminder',
      'daily_spending',
    ].contains(source)) {
      previousTap?.call(data);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Pending tap is retained until sign-in.
    if (data['uid'] != null && data['uid'] != user.uid) {
      NotificationService().consumePendingTap();
      return;
    }
    final navigator =
        (widget.navigatorKey ?? luxFinanceNavigatorKey).currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            (widget.navigatorKey ?? luxFinanceNavigatorKey).currentState !=
                null)
          _tap(data);
      });
      return;
    }
    unawaited(NotificationService().recordLocalTap(data));
    final id = data['debtId']?.toString();
    if (source == 'debt' || source == 'debt_local') {
      if (id == null || id.isEmpty) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => DebtDetailScreen(
            service: DebtFirebase(userId: user.uid),
            id: id,
          ),
        ),
      );
    } else {
      navigator.push(
        MaterialPageRoute(builder: (_) => const NotificationScreen()),
      );
    }
    NotificationService().consumePendingTap();
  }

  void _pending() {
    final data = NotificationService().pendingTap;
    if (data != null) _tap(data);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    previousTap = NotificationService().onNotificationTap;
    tapHandler = _tap;
    NotificationService().onNotificationTap = tapHandler;
    auth = FirebaseAuth.instance.authStateChanges().listen(_account);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pending();
    });
  }

  Future<void> _account(User? user) async {
    final version = ++generation;
    uid = user?.uid;
    await debts?.cancel();
    debts = null;
    try {
      await NotificationService().initialize();
      await NotificationService().cancelRemindersForOtherAccounts(uid);
    } catch (e) {
      debugPrint('Chưa hủy được lịch của phiên cũ: $e');
    }
    await DebtReminderService.instance.refreshSafely(null);
    if (!mounted || version != generation || uid == null) return;
    final id = uid!;
    try {
      await NotificationService().restoreSavedDailyReminder();
    } catch (e) {
      debugPrint('Chưa khôi phục được nhắc hằng ngày: $e');
    }
    if (!mounted || version != generation || uid != id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pending();
    });
    debts = FirebaseFirestore.instance
        .collection('debt_books')
        .doc(id)
        .collection('items')
        .snapshots()
        .listen(
          (_) {
            DebtReminderService.instance.refreshSafely(id);
          },
          onError: (Object e) {
            debugPrint('Không theo dõi được nhắc nợ: $e');
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DebtReminderService.instance.refreshSafely(uid);
      _pending();
    }
  }

  @override
  void dispose() {
    if (identical(NotificationService().onNotificationTap, tapHandler))
      NotificationService().onNotificationTap = previousTap;
    generation++;
    auth?.cancel();
    debts?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
