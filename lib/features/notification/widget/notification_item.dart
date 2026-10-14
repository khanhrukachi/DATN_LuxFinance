import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
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
      child: Material(
        color: notification.isRead ? SpendingStyle.card(context) : color.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: notification.isRead
                  ? SpendingStyle.teal.withOpacity(.16) : color.withOpacity(.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withOpacity(.13),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(_icon(), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(
                    _content(context, notification.title, 'test_title'),
                    style: TextStyle(fontSize: 15, height: 1.4,
                        fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800),
                  )),
                  if (!notification.isRead)
                    Padding(padding: const EdgeInsets.only(left: 8, top: 6),
                        child: Icon(Icons.circle, size: 8, color: color)),
                ]),
                const SizedBox(height: 7),
                Text(_content(context, notification.body, 'test_body'),
                    style: TextStyle(fontSize: 13, height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(.8))),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 13, color: SpendingStyle.muted(context)),
                  const SizedBox(width: 5),
                  Expanded(child: Text(_formatTime(context, notification.createdAt),
                      style: TextStyle(fontSize: 11, color: SpendingStyle.muted(context)))),
                ]),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}
