import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

/// Human-readable evidence; raw model fields and technical payloads stay hidden.
class ChatEvidenceCard extends StatelessWidget {
  const ChatEvidenceCard({super.key, required this.evidence});
  final Map<String, dynamic> evidence;

  @override
  Widget build(BuildContext context) {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    String t(String key) => AppLocalizations.of(context).translate(key);
    String money(dynamic n) => n is num && n.isFinite
        ? NumberFormat.currency(locale: vi ? 'vi_VN' : 'en_US', symbol: '₫', decimalDigits: 0).format(n)
        : '—';
    List<Map> rows(String key) => evidence[key] is List
        ? (evidence[key] as List).whereType<Map>().toList() : const [];
    Widget line(String title, String body) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(body, style: const TextStyle(height: 1.5)),
        ]));
    Widget section(String title, List<Widget> children) => Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
          tilePadding: EdgeInsets.zero, childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          children: [for (final child in children) SizedBox(width: double.infinity, child: child)]),
    );
    final widgets = <Widget>[];
    final categories = rows('categories').isNotEmpty ? rows('categories') : rows('topCategories');
    if (categories.isNotEmpty) widgets.add(section(t('chat_evidence_categories'), [
      for (final row in categories.take(50)) line('${row['categoryName'] ?? row['categoryId'] ?? ''}',
          row.containsKey('currentAmount')
              ? '${money(row['currentAmount'])} / ${money(row['previousAmount'])}'
              : row.containsKey('amount')
              ? '${money(row['amount'])}${row['sharePercent'] != null ? ' · ${row['sharePercent']}%' : ''} · ${row['transactionCount'] ?? row['count'] ?? 0} ${t('chat_evidence_transaction_count')}'
              : '${t('chat_evidence_parent_category')}: ${row['parentId'] ?? '—'}'),
    ]));
    final budgets = rows('budgets');
    if (budgets.isNotEmpty) widgets.add(section(t('chat_evidence_budgets'), [
      for (final row in budgets) line('${row['budgetName'] ?? row['category'] ?? ''}',
          '${t('chat_evidence_spent')}: ${money(row['spent'])} / ${money(row['limit'])}\n${t('chat_evidence_remaining')}: ${money(row['remaining'])}'),
    ]));
    final transactions = rows('transactions');
    if (transactions.isNotEmpty) widgets.add(section(t('chat_evidence_matching_transactions'), [
      for (final row in transactions) line('${row['categoryName'] ?? ''} · ${money(row['money'])}',
          '${row['dateTime'] ?? ''}\n${row['note'] ?? ''}'),
    ]));
    final daily = rows('daily');
    if (daily.isNotEmpty) widgets.add(section(t('chat_evidence_daily_forecast'), [
      for (final row in daily) line('${row['date'] ?? row['dateTime'] ?? row['date_time'] ?? ''}',
          '${t('chat_evidence_estimated_expense')}: ${money(row['predicted_expense'] ?? row['predictedExpense'])}\n${t('chat_evidence_estimated_income')}: ${money(row['predicted_income'] ?? row['predictedIncome'])}'),
    ]));
    final anomalies = rows('anomalies');
    if (anomalies.isNotEmpty) widgets.add(section(t('chat_evidence_transactions_to_review'), [
      for (final row in anomalies) line('${row['type_name'] ?? row['typeName'] ?? ''} · ${money(row['money'])}',
          '${row['anomaly_reason'] ?? row['anomalyReason'] ?? ''}'),
    ]));
    final clusters = rows('clusters');
    if (clusters.isNotEmpty) widgets.add(section(t('chat_evidence_spending_behavior'), [
      for (final row in clusters) line('${row['cluster_name'] ?? row['clusterName'] ?? ''}',
          '${row['description'] ?? ''}'),
    ]));
    final recommendations = rows('recommendations');
    if (recommendations.isNotEmpty) widgets.add(section(t('chat_evidence_items_to_review'), [
      for (final row in recommendations) line('${row['title'] ?? ''}',
          '${row['suggestion'] ?? row['reason'] ?? ''}'),
    ]));
    return widgets.isEmpty ? const SizedBox.shrink() : Column(children: widgets);
  }
}
