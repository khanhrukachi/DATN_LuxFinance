import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

Map<String, dynamic> reminderData(String? payload) {
  try {
    return Map<String, dynamic>.from(jsonDecode(payload ?? '') as Map);
  } catch (_) {
    return {};
  }
}

String reminderText(BuildContext context, String key) {
  if (key == 'filter_title') {
    return Localizations.localeOf(context).languageCode == 'en' ? 'Filters' : 'Bộ lọc';
  }
  return AppLocalizations.of(context).translate('reminder_$key');
}

String reminderErrorText(BuildContext context, Object error) {
  if (error is StateError) return error.message.toString();
  return reminderText(context, 'action_error');
}
