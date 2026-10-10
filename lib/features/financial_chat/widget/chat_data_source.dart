import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class ChatSnapshot {
  const ChatSnapshot(this.transactions, this.context);
  final List<Map<String, dynamic>> transactions;
  final Map<String, dynamic> context;
}

class ChatDataSource {
  ChatDataSource({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore db;
  String? _cachedUid;
  DateTime? _cachedAt;
  ChatSnapshot? _cached;
  void clearCache() { _cachedUid = null; _cachedAt = null; _cached = null; }

  Future<ChatSnapshot> load(String uid, {bool forceRefresh = false}) async {
    if (uid.trim().isEmpty) throw StateError('chat_login');
    if (!forceRefresh && _cachedUid == uid && _cached != null &&
        DateTime.now().difference(_cachedAt!).inSeconds < 30) return _cached!;
    final documents = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = db.collection('spending')
          .where('userId', isEqualTo: uid)
          .orderBy(FieldPath.documentId)
          .limit(500);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get();
      documents.addAll(page.docs);
      if (documents.length > 10000) throw StateError('chat_history_limit');
      if (page.docs.length < 500) break;
      cursor = page.docs.last;
    }
    final transactions = <Map<String, dynamic>>[];
    var complete = true;
    for (final doc in documents) {
      final row = doc.data();
      final rawDate = row['date'] ?? row['dateTime'];
      final date = rawDate is Timestamp ? rawDate.toDate()
          : rawDate is String ? DateTime.tryParse(rawDate) : null;
      if (date == null || row['money'] is! num) {
        complete = false; continue;
      }
      transactions.add({
        'id': doc.id,
        'money': (row['money'] as num).toInt(),
        if (row['type'] is num) 'type': (row['type'] as num).toInt(),
        'typeName': row['typeName']?.toString() ?? '',
        'dateTime': date.toUtc().toIso8601String(),
        'note': row['note']?.toString() ?? '',
        'merchant': row['merchant']?.toString() ?? row['location']?.toString() ?? '',
        if (row['isTransfer'] is bool) 'isTransfer': row['isTransfer'],
        if (row['categoryId'] != null) 'categoryId': row['categoryId'].toString(),
        if ((row['parentCategoryId'] ?? row['parentId']) != null)
          'parentCategoryId': (row['parentCategoryId'] ?? row['parentId']).toString(),
      });
    }
    final budgetDocs = await db.collection('budget').doc(uid).collection('items').get();
    int? integer(dynamic value) => value is num ? value.toInt() : int.tryParse('$value');
    final budgets = <Map<String, dynamic>>[];
    for (final doc in budgetDocs.docs) {
      final b = doc.data();
      final year = integer(b['year']);
      final month = integer(b['month']);
      if (year == null || month == null || month < 1 || month > 12 || b['isActive'] == false) continue;
      // Only analysis fields: do not send Firestore Timestamp/DocumentReference.
      budgets.add({
        'id': doc.id,
        if (b['name'] != null) 'name': b['name'].toString(),
        if (b['budgetName'] != null) 'budgetName': b['budgetName'].toString(),
        'year': year, 'month': month,
        'isActive': true,
        'limitMoney': integer(b['limitMoney']) ?? 0,
        if (integer(b['type']) != null) 'type': integer(b['type']),
        'typeName': b['typeName']?.toString() ?? '',
        if (b['categoryId'] != null) 'categoryId': b['categoryId'].toString(),
        if (b['parentCategoryId'] != null) 'parentCategoryId': b['parentCategoryId'].toString(),
      });
    }
    Map<String, dynamic> profile = {};
    try { profile = (await db.collection('info').doc(uid).get()).data() ?? {}; }
    on FirebaseException { /* Optional profile data must not block recorded totals. */ }
    final result = ChatSnapshot(transactions, {
      'budgets': budgets, 'history_complete': complete,
      'timezone': 'Asia/Ho_Chi_Minh',
      'snapshot_at': DateTime.now().toUtc().toIso8601String(),
      if (profile['averageMonthlyIncome'] is num)
        'average_monthly_income': profile['averageMonthlyIncome'],
    });
    _cachedUid = uid; _cachedAt = DateTime.now(); _cached = result;
    return result;
  }
}
