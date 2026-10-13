import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal_financial_management/features/spending/add_spending/widget/spending_style.dart';
import 'package:personal_financial_management/features/main/debt/widget/debt_category_widgets.dart';
import '../utils/reminder_helpers.dart';

class ReminderScheduleTile extends StatelessWidget {
  final PendingNotificationRequest notification;
  final String kind;
  final String timing;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;
  const ReminderScheduleTile({super.key,required this.notification,required this.kind,required this.timing,this.onCancel,this.onTap});
  @override Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.only(top:12),
    decoration:SpendingStyle.decoration(context),
    child:Material(color:Colors.transparent,borderRadius:BorderRadius.circular(20),clipBehavior:Clip.antiAlias,child:ListTile(
      contentPadding:const EdgeInsets.all(16),
      leading:kind=='debt' ? DebtCategoryIcon(id:reminderData(notification.payload)['categoryId']?.toString() ?? 'loan') : const SpendingFieldIcon(icon:Icons.alarm),
      title:Text(notification.title ?? 'LuxFinance',style:const TextStyle(fontWeight:FontWeight.w700)),
      subtitle:Text('$timing${notification.body==null ? '' : '\n${notification.body}'}'),
      trailing:IconButton(tooltip:reminderText(context,'cancel_schedule'),icon:const Icon(Icons.notifications_off_outlined),onPressed:onCancel),
      onTap:onTap,
    )),
  );
}
