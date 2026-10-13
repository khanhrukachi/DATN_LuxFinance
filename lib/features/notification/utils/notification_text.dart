import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class NotificationText {
  static String get(BuildContext context, String key) {
    return AppLocalizations.of(context).translate('notification_$key');
  }
}
