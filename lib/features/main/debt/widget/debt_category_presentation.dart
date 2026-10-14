import 'package:flutter/material.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/core/constants/list.dart';

class DebtCategoryPresentation {
  static String id(String direction) =>
      direction == 'borrow' ? 'borrow' : 'loan';

  static String paymentId(String direction) =>
      direction == 'borrow' ? 'pay' : 'debt_collection';

  static Map<String, String> item(String id) => listType.firstWhere(
    (e) => e['id'] == id,
    orElse: () => {'id': id, 'title': id},
  );

  static String title(BuildContext context, String id) {
    final key = item(id)['title'] ?? id;
    final translated = AppLocalizations.of(context).translate(key);
    if (translated.isNotEmpty && translated != key) return translated;
    final english = Localizations.localeOf(context).languageCode == 'en';
    return (english
            ? {
                'loan': 'Lend',
                'borrow': 'Borrow',
                'pay': 'Repay debt',
                'debt_collection': 'Collect debt',
                'pay_interest': 'Interest payment',
              }
            : {
                'loan': 'Cho vay',
                'borrow': 'Đi vay',
                'pay': 'Trả nợ',
                'debt_collection': 'Thu nợ',
                'pay_interest': 'Trả lãi',
              })[id] ??
        key;
  }
}
