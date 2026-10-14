import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_category_icon.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import '../utils/reminder_helpers.dart';

class ReminderScheduleTile extends StatelessWidget {
  final PendingNotificationRequest notification;
  final String kind;
  final String timing;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;
  const ReminderScheduleTile({super.key, required this.notification,
    required this.kind, required this.timing, this.onCancel, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    decoration: SpendingStyle.decoration(context),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (kind == 'debt')
              DebtCategoryIcon(id: reminderData(notification.payload)['categoryId']?.toString() ?? 'loan')
            else
              SpendingFieldIcon(icon: kind == 'daily' ? Icons.update_rounded : Icons.alarm_rounded),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(notification.title ?? 'LuxFinance',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.schedule_rounded, size: 15, color: SpendingStyle.accent(context)),
                const SizedBox(width: 5),
                Expanded(child: Text(timing, style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600, height: 1.4, color: SpendingStyle.accent(context)))),
              ]),
              if (notification.body?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(notification.body!, style: TextStyle(fontSize: 13, height: 1.5,
                    color: SpendingStyle.muted(context))),
              ],
            ])),
            const SizedBox(width: 6),
            IconButton(
              tooltip: reminderText(context, 'cancel_schedule'),
              icon: Icon(Icons.notifications_off_outlined,
                  color: onCancel == null ? SpendingStyle.muted(context).withOpacity(.4)
                      : SpendingStyle.muted(context)),
              onPressed: onCancel,
            ),
          ]),
        ),
      ),
    ),
  );
}
