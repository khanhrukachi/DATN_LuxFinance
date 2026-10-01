import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_financial_management/models/notification.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Android/iOS native Firebase configuration must be present.
  await Firebase.initializeApp();
  await NotificationService.saveNotificationToFirestore(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'luxfinance_notifications';
  static const String _channelName = 'Thông báo LuxFinance';
  static const String _channelDescription =
      'Thông báo cảnh báo chi tiêu và gợi ý từ AI';

  Future<void>? _initialization;
  bool _ready = false;
  void Function(Map<String, dynamic>)? onNotificationTap;
  Map<String, dynamic>? pendingTap;

  Future<void> initialize() {
    return _initialization ??= _initialize().catchError((Object error) {
      _initialization = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _requestPermission();
    await _initializeLocalNotifications();
    // Only the local plugin presents foreground messages, avoiding two banners.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false, badge: false, sound: false,
    );
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    await _saveFCMToken();
    _ready = true;
    _setupFCMHandlers();

    _messaging.onTokenRefresh.listen((token) async {
      try {
        await _updateFCMToken(token);
      } catch (e) {
        debugPrint('Token update failed: $e');
      }
    });
    if (launch?.didNotificationLaunchApp ?? false) {
      final response = launch?.notificationResponse;
      if (response != null) _onNotificationTapped(response);
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  void _deliverTap(Map<String, dynamic> data) {
    pendingTap = data;
    try {
      onNotificationTap?.call(data);
    } catch (e) {
      debugPrint('Notification navigation failed: $e');
    }
  }

  Map<String, dynamic>? consumePendingTap() {
    final value = pendingTap;
    pendingTap = null;
    return value;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) _deliverTap(decoded);
    } catch (e) {
      debugPrint('Invalid notification payload: $e');
    }
  }

  void _setupFCMHandlers() {
    FirebaseMessaging.onMessage.listen((message) async {
      try {
        await _saveRemoteMessage(message, showLocal: true);
      } catch (e) {
        debugPrint('Foreground notification failed: $e');
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _deliverTap(Map<String, dynamic>.from(message.data));
    });
    _messaging.getInitialMessage().then((message) {
      if (message != null) _deliverTap(Map<String, dynamic>.from(message.data));
    }).catchError((Object e) {
      debugPrint('Initial notification failed: $e');
    });
  }

  Future<void> _saveFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {

        await _updateFCMToken(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _updateFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM token saved to Firestore');
      } catch (e) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('FCM token saved to Firestore (merged)');
      }
    }
  }

  static Future<void> saveNotificationToFirestore(RemoteMessage message) =>
      _saveRemoteMessage(message, showLocal: false);

  static Future<void> _saveRemoteMessage(
      RemoteMessage message, {required bool showLocal}
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // uid is optional for legacy messages; backend should always include it.
    final recipient = message.data['uid'];
    if (recipient != null && recipient != user.uid) return;
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if (title == null && body == null) return;
    await NotificationService().createNotification(
      title: title?.toString() ?? 'LuxFinance',
      body: body?.toString() ?? '',
      type: message.data['type']?.toString() ?? 'reminder',
      deduplicationKey: message.data['deduplicationKey']?.toString() ??
          message.messageId,
      data: Map<String, dynamic>.from(message.data),
      showLocal: showLocal,
    );
  }

  Future<bool> createNotification({
    required String title,
    required String body,
    String type = 'reminder',
    String? deduplicationKey,
    Map<String, dynamic> data = const {},
    bool showLocal = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Bạn cần đăng nhập.');
    if (title.trim().isEmpty) throw ArgumentError('Tiêu đề không được trống.');
    if (showLocal && !_ready) {
      throw StateError('Gọi NotificationService().initialize() trước.');
    }
    final collection = FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('notifications');
    final key = deduplicationKey?.trim();
    if (key != null && (key.isEmpty || utf8.encode(key).length > 800)) {
      throw ArgumentError('Khóa chống trùng cần dài từ 1 đến 800 byte.');
    }
    final ref = key == null
        ? collection.doc()
        : collection.doc('key_${base64Url.encode(utf8.encode(key))}');
    final record = <String, dynamic>{
      'title': title.trim(), 'body': body, 'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false, 'isDeleted': false, 'data': data,
      if (key != null) 'deduplicationKey': key,
    };
    final created = await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) return false;
      tx.set(ref, record);
      return true;
    });
    if (created && showLocal &&
        FirebaseAuth.instance.currentUser?.uid == user.uid) {
      try {
        await showLocalNotification(
          id: _stableId('${user.uid}/${ref.id}'),
          title: title, body: body,
          data: {...data, 'uid': user.uid, 'notificationId': ref.id},
        );
      } catch (e) {
        debugPrint('Notification saved; local display failed: $e');
      }
    }
    return created;
  }

  static int _stableId(String value) {
    var hash = 0;
    for (final byte in utf8.encode(value)) {
      hash = (hash * 31 + byte) & 0x7fffffff;
    }
    return hash;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high, priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
    ),
  );

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (!_ready) throw StateError('Gọi initialize() trước.');
    await _localNotifications.show(
      id, title, body, _details, payload: jsonEncode(data),
    );
  }

  Future<void> scheduleDailyReminder({
    int id = 2000000001,
    int hour = 20,
    int minute = 0,
    String timeZone = 'Asia/Ho_Chi_Minh',
    String title = 'Ghi lại chi tiêu hôm nay',
    String body = 'Cập nhật các khoản thu chi để theo dõi ngân sách của bạn.',
  }) async {
    if (!_ready) throw StateError('Gọi initialize() trước.');
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Giờ phải từ 0–23, phút từ 0–59.');
    }
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Bạn cần đăng nhập.');
    }
    final location = tz.getLocation(timeZone);
    final now = tz.TZDateTime.now(location);
    var next = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(location, now.year, now.month, now.day + 1, hour, minute);
    }
    debugPrint('Giờ hiện tại: $now');
    debugPrint('Lần nhắc tiếp theo: $next');

    await _localNotifications.zonedSchedule(
      id, title, body, next, _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': 'reminder'}),
    );
  }

  Future<void> scheduleReminder({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    String timeZone = 'Asia/Ho_Chi_Minh',
  }) async {
    if (!_ready) throw StateError('Gọi initialize() trước.');
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Bạn cần đăng nhập.');
    }
    if (!scheduledAt.isAfter(DateTime.now())) {
      throw ArgumentError('Thời điểm nhắc phải ở tương lai.');
    }
    await _localNotifications.zonedSchedule(
      id, title, body,
      tz.TZDateTime.from(scheduledAt, tz.getLocation(timeZone)), _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': 'reminder'}),
    );
  }

  Future<void> cancelReminder(int id) => _localNotifications.cancel(id);
  Future<void> cancelAllReminders() => _localNotifications.cancelAll();
  Future<List<PendingNotificationRequest>> getPendingReminders() =>
      _localNotifications.pendingNotificationRequests();

  /// Call after login; initialize() may have run before a user signed in.
  Future<void> refreshToken() => _saveFCMToken();

  /// Call BEFORE FirebaseAuth.signOut(). Also cancels device-local reminders.
  Future<void> clearSession() async {
    await _localNotifications.cancelAll();
    final user = FirebaseAuth.instance.currentUser;
    final token = await _messaging.getToken();
    if (user != null && token != null) {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final doc = await tx.get(ref);
        if (doc.data()?['fcmToken'] == token) {
          tx.update(ref, {
            'fcmToken': FieldValue.delete(),
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }
    await _messaging.deleteToken();
    pendingTap = null;
  }

  Stream<List<NotificationModel>> getNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .where((doc) => doc.data()['isDeleted'] != true)
        .map((doc) => NotificationModel.fromFirestore(doc))
        .toList());
  }

  Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final collection = FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('notifications');
    while (true) {
      final unread = await collection
          .where('isRead', isEqualTo: false).limit(400).get();
      if (unread.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isDeleted': true, 'isRead': true});
    // Soft delete keeps the deduplication key after dismissal.
    await _localNotifications.cancel(_stableId('${user.uid}/$notificationId'));
  }

  Stream<int> getUnreadCountStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.where((d) => d.data()['isDeleted'] != true).length);
  }
}