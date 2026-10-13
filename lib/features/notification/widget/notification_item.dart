import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/notification.dart';
import '../utils/notification_text.dart';

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const NotificationItem({
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
    if (diff.inMinutes < 1) return NotificationText.get(context, 'just_now');
    if (diff.inHours < 1) {
      return NotificationText.get(context,
          diff.inMinutes == 1 ? 'minute_one' : 'minute_many')
          .replaceAll('{count}', diff.inMinutes.toString());
    }
    if (diff.inDays < 1) {
      return NotificationText.get(context,
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
        ? NotificationText.get(context, key)
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
          message: NotificationText.get(context, 'delete'),
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
