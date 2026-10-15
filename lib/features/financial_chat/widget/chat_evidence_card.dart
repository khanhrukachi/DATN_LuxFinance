import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'chat_evidence_line.dart';
import '../utils/chat_category_label.dart';
import 'chat_evidence_section.dart';

/// Human-readable evidence; raw model fields and technical payloads stay hidden.
class ChatEvidenceCard extends StatelessWidget {
  const ChatEvidenceCard({super.key, required this.evidence, this.categoryCatalog = const []});
  final Map<String, dynamic> evidence;
  final List<Map<String, dynamic>> categoryCatalog;

  @override
  Widget build(BuildContext context) {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    String money(dynamic n) => n is num && n.isFinite
        ? NumberFormat.currency(
            locale: vi ? 'vi_VN' : 'en_US',
            symbol: '₫',
            decimalDigits: 0,
          ).format(n)
        : AppLocalizations.of(context).translate('financial_chat_not_available');
    List<Map> rows(String key) => evidence[key] is List
        ? (evidence[key] as List).whereType<Map>().toList()
        : const [];
    final widgets = <Widget>[];
    final categories = rows('categories').isNotEmpty
        ? rows('categories')
        : rows('topCategories');
    if (categories.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: AppLocalizations.of(context).translate('financial_chat_evidence_categories'),
          children: [
            for (final row in categories.take(50))
              ChatEvidenceLine(
                title: chatCategoryLabel(context, row['categoryName'] ?? row['categoryId'], catalog: categoryCatalog),
                body: row.containsKey('currentAmount')
                    ? AppLocalizations.of(context).translate('financial_chat_category_amount_comparison').replaceAll('{current}', money(row['currentAmount'])).replaceAll('{previous}', money(row['previousAmount']))
                    : row.containsKey('amount')
                    ? AppLocalizations.of(context).translate('financial_chat_category_amount_summary').replaceAll('{amount}', money(row['amount'])).replaceAll('{share}', row['sharePercent'] != null ? ' · ${row['sharePercent']}%' : '').replaceAll('{count}', '${row['transactionCount'] ?? row['count'] ?? 0}')
                    : '${AppLocalizations.of(context).translate('financial_chat_evidence_parent_category')}: ${chatCategoryLabel(context, row['parentId'], catalog: categoryCatalog)}',
              ),
          ],
        ),
      );
    }
    final budgets = rows('budgets');
    if (budgets.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: AppLocalizations.of(context).translate('financial_chat_evidence_budgets'),
          children: [
            for (final row in budgets)
              ChatEvidenceLine(
                title: chatCategoryLabel(context, row['budgetName'] ?? row['categoryId'] ?? row['category'], catalog: categoryCatalog),
                body:
                    AppLocalizations.of(context).translate('financial_chat_budget_summary').replaceAll('{spent}', money(row['spent'])).replaceAll('{limit}', money(row['limit'])).replaceAll('{remaining}', money(row['remaining'])),
              ),
          ],
        ),
      );
    }
    final transactions = rows('transactions');
    if (transactions.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: AppLocalizations.of(context).translate('financial_chat_evidence_matching_transactions'),
          children: [
            for (final row in transactions)
              ChatEvidenceLine(
                title: '${chatCategoryLabel(context, row['categoryName'] ?? row['categoryId'], catalog: categoryCatalog)} · ${money(row['money'])}',
                body: '${row['dateTime'] ?? ''}\n${row['note'] ?? ''}',
              ),
          ],
        ),
      );
    }
    final daily = rows('daily');
    if (daily.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: AppLocalizations.of(context).translate('financial_chat_evidence_daily_forecast'),
          children: [
            for (final row in daily)
              ChatEvidenceLine(
                title: '${row['date'] ?? row['dateTime'] ?? row['date_time'] ?? ''}',
                body:
                    AppLocalizations.of(context).translate('financial_chat_forecast_summary').replaceAll('{expense}', money(row['predicted_expense'] ?? row['predictedExpense'])).replaceAll('{income}', money(row['predicted_income'] ?? row['predictedIncome'])),
              ),
          ],
        ),
      );
    }
    final anomalies = rows('anomalies');
    if (anomalies.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: AppLocalizations.of(context).translate('financial_chat_evidence_transactions_to_review'),
          children: [
            for (final row in anomalies)
              ChatEvidenceLine(
                title: '${chatCategoryLabel(context, row['type_name'] ?? row['typeName'] ?? row['categoryId'], catalog: categoryCatalog)} · ${money(row['money'])}',
                body: '${row['anomaly_reason'] ?? row['anomalyReason'] ?? ''}',
              ),
          ],
        ),
      );
    }
    final clusters = rows('clusters');
    if (clusters.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: AppLocalizations.of(context).translate('financial_chat_evidence_spending_behavior'),
          children: [
            for (final row in clusters)
              ChatEvidenceLine(
                title: '${row['cluster_name'] ?? row['clusterName'] ?? ''}',
                body: '${row['description'] ?? ''}',
              ),
          ],
        ),
      );
    }
    final recommendations = rows('recommendations');
    if (recommendations.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: AppLocalizations.of(context).translate('financial_chat_evidence_items_to_review'),
          children: [
            for (final row in recommendations)
              ChatEvidenceLine(
                title: '${row['title'] ?? ''}',
                body: '${row['suggestion'] ?? row['reason'] ?? ''}',
              ),
          ],
        ),
      );
    }
    return widgets.isEmpty ? const SizedBox.shrink() : Column(children: widgets);
  }
}
