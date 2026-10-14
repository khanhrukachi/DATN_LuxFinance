import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

import 'chat_evidence_line.dart';
import 'chat_evidence_section.dart';

/// Human-readable evidence; raw model fields and technical payloads stay hidden.
class ChatEvidenceCard extends StatelessWidget {
  const ChatEvidenceCard({super.key, required this.evidence});
  final Map<String, dynamic> evidence;

  @override
  Widget build(BuildContext context) {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    String t(String key) => AppLocalizations.of(context).translate(key);
    String money(dynamic n) => n is num && n.isFinite
        ? NumberFormat.currency(
            locale: vi ? 'vi_VN' : 'en_US',
            symbol: '₫',
            decimalDigits: 0,
          ).format(n)
        : '—';
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
          title: t('chat_evidence_categories'),
          children: [
            for (final row in categories.take(50))
              ChatEvidenceLine(
                title: '${row['categoryName'] ?? row['categoryId'] ?? ''}',
                body: row.containsKey('currentAmount')
                    ? '${money(row['currentAmount'])} / ${money(row['previousAmount'])}'
                    : row.containsKey('amount')
                    ? '${money(row['amount'])}${row['sharePercent'] != null ? ' · ${row['sharePercent']}%' : ''} · ${row['transactionCount'] ?? row['count'] ?? 0} ${t('chat_evidence_transaction_count')}'
                    : '${t('chat_evidence_parent_category')}: ${row['parentId'] ?? '—'}',
              ),
          ],
        ),
      );
    }
    final budgets = rows('budgets');
    if (budgets.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: t('chat_evidence_budgets'),
          children: [
            for (final row in budgets)
              ChatEvidenceLine(
                title: '${row['budgetName'] ?? row['category'] ?? ''}',
                body:
                    '${t('chat_evidence_spent')}: ${money(row['spent'])} / ${money(row['limit'])}\n${t('chat_evidence_remaining')}: ${money(row['remaining'])}',
              ),
          ],
        ),
      );
    }
    final transactions = rows('transactions');
    if (transactions.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: t('chat_evidence_matching_transactions'),
          children: [
            for (final row in transactions)
              ChatEvidenceLine(
                title: '${row['categoryName'] ?? ''} · ${money(row['money'])}',
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
          title: t('chat_evidence_daily_forecast'),
          children: [
            for (final row in daily)
              ChatEvidenceLine(
                title: '${row['date'] ?? row['dateTime'] ?? row['date_time'] ?? ''}',
                body:
                    '${t('chat_evidence_estimated_expense')}: ${money(row['predicted_expense'] ?? row['predictedExpense'])}\n${t('chat_evidence_estimated_income')}: ${money(row['predicted_income'] ?? row['predictedIncome'])}',
              ),
          ],
        ),
      );
    }
    final anomalies = rows('anomalies');
    if (anomalies.isNotEmpty) {
      widgets.add(
        ChatEvidenceSection(
          title: t('chat_evidence_transactions_to_review'),
          children: [
            for (final row in anomalies)
              ChatEvidenceLine(
                title: '${row['type_name'] ?? row['typeName'] ?? ''} · ${money(row['money'])}',
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
          title: t('chat_evidence_spending_behavior'),
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
          title: t('chat_evidence_items_to_review'),
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
