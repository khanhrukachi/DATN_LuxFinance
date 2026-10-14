import 'widget/reminder_navigation_button.dart';
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
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 48,
        leading: BackButton(color: SpendingStyle.accent(context)),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(_text('title'), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          ReminderToolbarButton(
            tooltip: _text('schedule_tooltip'),
            icon: Icons.alarm_outlined,
            onPressed: _uid == null ? null : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReminderScheduleScreen()),
            ),
          ),
          if (kDebugMode)
          ReminderToolbarButton(
            tooltip: _text('mark_all'),
            icon: Icons.done_all_rounded,
            loading: _markingAll,
            onPressed: _uid == null || unread == 0 || _markingAll ? null : _markAllRead,
          ),
          const SizedBox(width: 16),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: SpendingStyle.teal.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 38,
                    color: SpendingStyle.accent(context),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _text('empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: SpendingStyle.muted(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final unread = _notifications.where((n) => !n.isRead).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ReminderInfoPanel(
          icon: Icons.notifications_active_outlined,
          title: _text('unread_summary').replaceAll('{count}', unread.toString()),
          subtitle: _text('total_summary').replaceAll('{count}', _notifications.length.toString()),
          hero: true,
        ),
        const SizedBox(height: 16),
        for (final notification in _notifications)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NotificationItem(
              key: ValueKey(notification.id),
              notification: notification,
              onTap: () => _open(notification),
              onDelete: () => _delete(notification),
            ),
          ),
      ],
    );
  }
}
