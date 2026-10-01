import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/notification_service.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/notification.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
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

  String _text(String key) => _NotificationText.get(context, key);

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
      _message(created
          ? _text('test_saved')
          : _text('test_duplicate'));
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_text('title')),
        centerTitle: true,
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: _text('test_tooltip'),
              onPressed: _uid == null || _testing ? null : _testNotification,
              icon: _testing
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_alert_outlined),
            ),
          IconButton(
            tooltip: _text('mark_all'),
            onPressed: _uid == null || unread == 0 || _markingAll
                ? null : _markAllRead,
            icon: _markingAll
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
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
            Icon(Icons.notifications_none_rounded, size: 80,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
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
        return _NotificationItem(
          key: ValueKey(notification.id),
          notification: notification,
          onTap: () => _markRead(notification),
          onDelete: () => _delete(notification),
        );
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  Color _color() {
    switch (notification.type) {
      case 'warning':
        return Colors.orange;
      case 'danger':
        return Colors.redAccent;
      case 'info':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _icon() {
    switch (notification.type) {
      case 'warning':
        return Icons.warning_rounded;
      case 'danger':
        return Icons.error_rounded;
      case 'info':
        return Icons.info_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatTime(BuildContext context, DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return _NotificationText.get(context, 'just_now');
    if (diff.inHours < 1) {
      return _NotificationText.get(context,
          diff.inMinutes == 1 ? 'minute_one' : 'minute_many')
          .replaceAll('{count}', diff.inMinutes.toString());
    }
    if (diff.inDays < 1) {
      return _NotificationText.get(context,
          diff.inHours == 1 ? 'hour_one' : 'hour_many')
          .replaceAll('{count}', diff.inHours.toString());
    }
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    return DateFormat(isEnglish ? 'MM/dd/yyyy • HH:mm' : 'dd/MM/yyyy • HH:mm')
        .format(time.toLocal());
  }

  // The test record has a deterministic ID created by NotificationService.
  // Other Firestore content is displayed as provided by its source.
  String _content(BuildContext context, String value, String key) {
    final testId = 'key_${base64Url.encode(utf8.encode('notification_page_test_v1'))}';
    return notification.id == testId
        ? _NotificationText.get(context, key)
        : value;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      // Firestore drives removal; avoid dismissing a widget still in the list.
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Tooltip(
          message: _NotificationText.get(context, 'delete'),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: notification.isRead
                ? Theme.of(context).cardColor
                : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thanh màu bên trái (chưa đọc)
              if (!notification.isRead)
                Container(
                  width: 5,
                  height: 110,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: color.withOpacity(0.15),
                        child: Icon(_icon(), color: color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _content(context, notification.title, 'test_title'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _content(context, notification.body, 'test_body'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _formatTime(context, notification.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// All interface translations come from assets/lang/vn.json and en.json.
class _NotificationText {
  static String get(BuildContext context, String key) {
    return AppLocalizations.of(context).translate('notification_$key');
  }
}
