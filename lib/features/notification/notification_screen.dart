import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:personal_financial_management/controls/debt_firebase.dart';
import 'package:personal_financial_management/features/main/debt/debt_book_screen.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/features/notification/reminder_schedule_screen.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/controls/notification_service.dart';
import 'package:personal_financial_management/models/notification.dart';
import 'widget/notification_item.dart';
import 'utils/notification_text.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _service = NotificationService();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<NotificationModel>>? _subscription;
  List<NotificationModel> _notifications = [];
  final Set<String> _busyIds = {};
  String? _uid;
  String? _error;
  bool _loading = true;
  bool _markingAll = false;
  bool _testing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      _uid = user?.uid;
      _listen();
    });
  }

  void _listen() {
    final generation = ++_generation;
    _subscription?.cancel();
    setState(() {
      _notifications = [];
      _busyIds.clear();
      _error = null;
      _loading = _uid != null;
    });
    if (_uid == null) return;
    _subscription = _service.getNotificationsStream().listen(
      (items) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _notifications = items;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object error) {
        debugPrint('Notification stream failed: $error');
        if (!mounted || generation != _generation) return;
        setState(() {
          _loading = false;
          _error = 'load_error';
        });
      },
    );
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  String _text(String key) => NotificationText.get(context, key);

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markRead(NotificationModel notification) async {
    if (notification.isRead || _busyIds.contains(notification.id)) return;
    final generation = _generation;
    _busyIds.add(notification.id);
    try {
      await _service.markAsRead(notification.id);
    } catch (e) {
      debugPrint('Mark notification read failed: $e');
      if (mounted && generation == _generation) _message(_text('read_error'));
    } finally {
      if (generation == _generation) _busyIds.remove(notification.id);
    }
  }

  Future<void> _open(NotificationModel notification) async {
    final uid = _uid;
    if (uid == null) return;
    await _markRead(notification);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notification.id)
          .get();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final raw = doc.data()?['data'];
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      if (data['source'] == 'debt' || data['source'] == 'debt_local') {
        final id = data['debtId']?.toString();
        if (id != null && id.isNotEmpty) {
          await Navigator.push(
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
    } catch (e) {
      debugPrint('Open notification target failed: $e');
      if (mounted) _message(_text('open_error'));
    }
  }

  Future<void> _delete(NotificationModel notification) async {
    if (_busyIds.contains(notification.id)) return;
    final generation = _generation;
    _busyIds.add(notification.id);
    try {
      await _service.deleteNotification(notification.id);
    } catch (e) {
      debugPrint('Delete notification failed: $e');
      if (mounted && generation == _generation) _message(_text('delete_error'));
    } finally {
      if (generation == _generation) _busyIds.remove(notification.id);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _service.markAllAsRead();
    } catch (e) {
      debugPrint('Mark all read failed: $e');
      if (mounted) _message(_text('read_all_error'));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _testNotification() async {
    if (_testing) return;
    final uid = _uid;
    if (uid == null) return;
    setState(() => _testing = true);
    try {
      await _service.initialize();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final created = await _service.createNotification(
        title: _text('test_title'),
        body: _text('test_body'),
        type: 'info',
        deduplicationKey: 'notification_page_test_v1',
      );
      if (!mounted) return;
      _message(created ? _text('test_saved') : _text('test_duplicate'));
    } catch (e) {
      debugPrint('Test notification failed: $e');
      if (mounted) _message(_text('test_error'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;
    return Scaffold(
      backgroundColor: SpendingStyle.background(context),
      appBar: AppBar(
        backgroundColor: SpendingStyle.background(context),
        title: Text(_text('title')),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _text('schedule_tooltip'),
            icon: const Icon(Icons.alarm_outlined),
            onPressed: _uid == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReminderScheduleScreen(),
                    ),
                  ),
          ),
          if (kDebugMode)
            IconButton(
              tooltip: _text('test_tooltip'),
              onPressed: _uid == null || _testing ? null : _testNotification,
              icon: _testing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_alert_outlined),
            ),
          IconButton(
            tooltip: _text('mark_all'),
            onPressed: _uid == null || unread == 0 || _markingAll
                ? null
                : _markAllRead,
            icon: _markingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_uid == null) {
      return Center(child: Text(_text('sign_in')));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_text(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _listen, child: Text(_text('retry'))),
            ],
          ),
        ),
      );
    }
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(_text('empty')),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return NotificationItem(
          key: ValueKey(notification.id),
          notification: notification,
          onTap: () => _open(notification),
          onDelete: () => _delete(notification),
        );
      },
    );
  }
}
