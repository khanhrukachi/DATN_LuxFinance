import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class NotificationText {
  static String get(BuildContext context, String key) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    if (key == 'unread_summary') {
      return english ? '{count} unread notifications' : '{count} thông báo chưa đọc';
    }
    if (key == 'total_summary') {
      return english ? '{count} notifications in total' : 'Tổng cộng {count} thông báo';
    }
    return AppLocalizations.of(context).translate('notification_$key');
  }
}
