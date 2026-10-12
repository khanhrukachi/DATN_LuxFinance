import 'wallet_firebase.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:personal_financial_management/controls/notification_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/models/budget.dart';
import 'package:personal_financial_management/models/user.dart' as myuser;
import 'package:personal_financial_management/core/constants/list.dart';

class SpendingFirebase {
  static String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if(uid == null) throw StateError('Bạn cần đăng nhập');
    return uid;
  }
  static void _owner(Map<String,dynamic> data, String uid) {
    if(data['userId'] != uid) throw StateError('Không có quyền sửa giao dịch này');
  }
  static Future<void> _deleteImageSafely(String? url) async {
    if(url == null || !url.startsWith('https://')) return;
    try { await FirebaseStorage.instance.refFromURL(url).delete(); }
    catch(e) { debugPrint('Giao dịch đã lưu; chưa dọn được ảnh cũ: $e'); }
  }
  static Future<void> addSpending(Spending spending, {String? categoryId,String? parentId,String? parentName}) async {
    if(spending.type<0 || spending.type>=listType.length) throw StateError('Danh mục không hợp lệ');
    if(isDebtCategory(listType[spending.type])) throw StateError('Vay, cho vay, thu/trả nợ được quản lý trong Sổ nợ, không thêm vào chi tiêu.');
    final uid = _uid;
    final db = FirebaseFirestore.instance;
    // Keep document id on the draft for safe retry on this same draft.
    spending.id ??= db.collection('spending').doc().id;
    final ref = db.collection('spending').doc(spending.id);
    final dataRef = db.collection('data').doc(uid);
    if(spending.image != null && !spending.image!.startsWith('https://')) {
      spending.image = await uploadImage(folder:'spending',name:'${ref.id}_${DateTime.now().microsecondsSinceEpoch}.png',image:File(spending.image!));
    }
    final key = DateFormat('MM_yyyy').format(spending.dateTime);
    await db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx,db,uid);
      if(existing.exists) {
        _owner(existing.data()!,uid);
        return; // Same create id: no duplicate wallet increment.
      }
      wallet.apply(spending.money);
      tx.set(ref, {...spending.toMap(),'userId':uid,'categoryId':categoryId ?? spending.categoryId,'parentId':parentId ?? spending.parentId,'parentName':parentName ?? spending.parentName,'revision':0,'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
      tx.set(dataRef,{key:FieldValue.arrayUnion([ref.id])},SetOptions(merge:true));
    });
    spending.revision ??= 0;
    await _checkBudgetNotificationsSafely(uid:uid,month:spending.dateTime.month,year:spending.dateTime.year);
  }
  static Future<void> updateSpending(Spending spending,DateTime oldDay,File? image,bool deleteImage) async {
    if(spending.id == null) throw StateError('Giao dịch chưa có id');
    final uid = _uid;
    final db = FirebaseFirestore.instance;
    final ref = db.collection('spending').doc(spending.id);
    final initial = await ref.get();
    if(!initial.exists) throw StateError('Giao dịch đã bị xóa');
    _owner(initial.data()!,uid);
    final baseline = (initial.data()!['revision'] as num?)?.toInt() ?? 0;
    if(spending.revision != null && spending.revision != baseline) throw StateError('Giao dịch đã thay đổi từ khi mở màn hình. Hãy mở lại');
    final oldImage = initial.data()!['image'] as String?;
    String? newImage = oldImage;
    if(image != null) {
      newImage = await uploadImage(folder:'spending',name:'${ref.id}_${DateTime.now().microsecondsSinceEpoch}.png',image:image);
    } else if(deleteImage) { newImage = null; }
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx,db,uid);
      if(!snap.exists) throw StateError('Giao dịch đã bị xóa');
      final old = snap.data()!;
      _owner(old,uid);
      final revision = (old['revision'] as num?)?.toInt() ?? 0;
      if(revision != baseline) throw StateError('Giao dịch vừa thay đổi. Hãy mở lại để sửa');
      final oldKey = DateFormat('MM_yyyy').format((old['date'] as Timestamp).toDate());
      final newKey = DateFormat('MM_yyyy').format(spending.dateTime);
      wallet.apply(spending.money-(old['money'] as num).toInt());
      final values = spending.toMap();
      // Preserve category metadata only if category did not change.
      if(old['type'] == spending.type) {
        for(final key in ['categoryId','parentId','parentName']) {
          if(values[key] == null && old.containsKey(key)) values[key]=old[key];
        }
      }
      tx.update(ref,{...values,'userId':uid,'image':newImage,'revision':revision+1,'updatedAt':FieldValue.serverTimestamp()});
      if(oldKey != newKey) tx.set(db.collection('data').doc(uid),{oldKey:FieldValue.arrayRemove([ref.id]),newKey:FieldValue.arrayUnion([ref.id])},SetOptions(merge:true));
    });
    spending.image = newImage;
    spending.revision = baseline + 1;
    if(oldImage != newImage) await _deleteImageSafely(oldImage);
    await _checkBudgetNotificationsSafely(uid:uid,month:spending.dateTime.month,year:spending.dateTime.year);
  }
  static Future<void> deleteSpending(Spending spending) async {
    if(spending.id == null) throw StateError('Giao dịch chưa có id');
    final uid = _uid; final db = FirebaseFirestore.instance;
    final ref = db.collection('spending').doc(spending.id);
    String? oldImage;
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx,db,uid);
      if(!snap.exists) return; // Repeated delete never refunds twice.
      final old = snap.data()!;
      _owner(old,uid);
      if(spending.revision != null && spending.revision != ((old['revision'] as num?)?.toInt() ?? 0)) throw StateError('Giao dịch đã thay đổi. Hãy mở lại trước khi xóa');
      oldImage = old['image'] as String?;
      final key = DateFormat('MM_yyyy').format((old['date'] as Timestamp).toDate());
      wallet.apply(-(old['money'] as num).toInt());
      tx.set(db.collection('data').doc(uid),{key:FieldValue.arrayRemove([ref.id])},SetOptions(merge:true));
      tx.delete(ref);
    });
    await _deleteImageSafely(oldImage);
  }
  // =====================================================
  // ================= EXPORT FOR AI =====================
  // =====================================================

  static Future<List<Spending>> getAllSpendingForAI() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final snap = await FirebaseFirestore.instance
        .collection("spending")
        .where("userId", isEqualTo: uid)
        .orderBy("date")
        .get();

    return snap.docs.map((e) => Spending.fromFirebase(e)).toList();
  }

  // =====================================================
  // ================= GET SPENDING LIST =====================
  // =====================================================

  static Future<List<Spending>> getSpendingList(List<String> ids) async {
    List<Spending> list = [];
    for (final id in ids) {
      final doc =
      await FirebaseFirestore.instance.collection("spending").doc(id).get();
      if (doc.exists && doc.data() != null) {
        list.add(Spending.fromFirebase(doc));
      }
    }
    return list;
  }

  // =====================================================
  // ================= ADD BUDGET ========================
  // =====================================================

  static Future<void> addOrUpdateBudget(Budget budget) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection("budget")
        .doc(uid)
        .collection("items")
        .doc("${budget.year}_${budget.month}_${budget.type}");

    await ref.set(budget.toMap(), SetOptions(merge: true));
    await _checkBudgetNotificationsSafely(
      uid: uid, month: budget.month, year: budget.year, onlyType: budget.type,
    );
  }

  static Future<List<Budget>> getBudgetsOfMonth(int month, int year) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection("budget")
        .doc(uid)
        .collection("items")
        .where("month", isEqualTo: month)
        .where("year", isEqualTo: year)
        .get();

    return snap.docs.map((e) => Budget.fromFirebase(e)).toList();
  }

  static Future<int> getTotalExpenseOfMonth({
    required int month,
    required int year,
    int? type,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    Query query = FirebaseFirestore.instance
        .collection("spending")
        .where("userId", isEqualTo: uid)
        .where("money", isLessThan: 0);

    final Set<int>? coveredTypes = type == null
        ? null
        : _budgetCategoryScope(type);

    if (coveredTypes != null) {
      if (coveredTypes.isEmpty) return 0;
      if (coveredTypes.length == 1) {
        query = query.where("type", isEqualTo: coveredTypes.first);
      } else if (coveredTypes.length <= 30) {
        query = query.where("type", whereIn: coveredTypes.toList());
      }
    }

    final snap = await query.get();

    int total = 0;
    for (var doc in snap.docs) {
      final spending = Spending.fromFirebase(doc);
      if (coveredTypes != null && !coveredTypes.contains(spending.type)) continue;
      if (spending.month == month && spending.year == year) {
        total += spending.money.abs();
      }
    }
    return total;
  }

  /// A parent budget covers direct spending on that parent and every nested
  /// expense category below it. Type 0 continues to represent all spending.
  static Set<int> _budgetCategoryScope(int selectedType) {
    if (selectedType < 0 || selectedType >= listType.length) return <int>{};

    final expenseRootId = listType[0]['id']?.toString() ?? 'expense';
    bool belongsToExpense(int index) {
      if (index == 0) return true;
      final visited = <String>{};
      var current = Map<String, dynamic>.from(listType[index] as Map);
      while (true) {
        final parentId = (current['legacyParent'] ?? current['parent'])?.toString() ?? '';
        if (parentId == expenseRootId) return true;
        if (parentId.isEmpty || !visited.add(parentId)) return false;
        final parentIndex = listType.indexWhere(
              (item) => item['id']?.toString() == parentId,
        );
        if (parentIndex < 0) return false;
        current = Map<String, dynamic>.from(listType[parentIndex] as Map);
      }
    }

    if (selectedType == 0) {
      return <int>{
        for (var i = 0; i < listType.length; i++)
          if (belongsToExpense(i)) i,
      };
    }

    final scope = <int>{selectedType};
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 1; i < listType.length; i++) {
        if (scope.contains(i) || !belongsToExpense(i)) continue;
        final parentId = (listType[i]['legacyParent'] ?? listType[i]['parent'])?.toString() ?? '';
        final parentIndex = listType.indexWhere(
              (item) => item['id']?.toString() == parentId,
        );
        if (scope.contains(parentIndex)) {
          scope.add(i);
          changed = true;
        }
      }
    }
    return scope;
  }

  static Future<bool> isOverBudget(Budget budget) async {
    final spent = await getTotalExpenseOfMonth(
      month: budget.month,
      year: budget.year,
      type: budget.type == 0 ? null : budget.type,
    );
    return spent > budget.limitMoney;
  }

  static Future<void> updateBudget({
    required Budget budget,
    required int newLimit,
  }) async {
    if (budget.id == null) {
      throw Exception("Budget document không tồn tại!");
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection("budget")
        .doc(uid)
        .collection("items")
        .doc(budget.id);

    await ref.update({
      "limitMoney": newLimit,
      "updatedAt": FieldValue.serverTimestamp(),
    });
    // Re-read the stored budget so the check uses the new limit.
    await _checkBudgetNotificationsSafely(
      uid: uid, month: budget.month, year: budget.year, onlyType: budget.type,
    );
  }


  // BUDGET NOTIFICATIONS: Vietnamese by default. Set the active app language
  // using setNotificationLanguage(Localizations.localeOf(context).languageCode).
  static String _notificationLanguage = 'vi';
  static final Map<String, Map<String, dynamic>> _translations = {};

  static void setNotificationLanguage(String code) {
    _notificationLanguage = code.toLowerCase().startsWith('en') ? 'en' : 'vi';
  }

  static Future<Map<String, dynamic>> _loadTranslations(String language) async {
    if (_translations.containsKey(language)) return _translations[language]!;
    try {
      final path = language == 'en' ? 'assets/lang/en.json' : 'assets/lang/vn.json';
      final values = Map<String, dynamic>.from(
        jsonDecode(await rootBundle.loadString(path)) as Map,
      );
      _translations[language] = values;
      return values;
    } catch (e) {
      debugPrint('Budget translations unavailable: $e');
      return {};
    }
  }

  /// Optional manual check. Existing mutation methods call this automatically.
  static Future<void> checkBudgetNotifications({
    required int month, required int year,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _checkBudgetNotificationsSafely(uid: uid, month: month, year: year);
  }

  static Future<void> _checkBudgetNotificationsSafely({
    required String uid,
    required int month,
    required int year,
    int? onlyType,
  }) async {
    try {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      final now = DateTime.now().toUtc().add(const Duration(hours: 7));
      // Do not send outdated alerts when the user edits historical transactions.
      if (month != now.month || year != now.year) return;
      final db = FirebaseFirestore.instance;
      final budgetSnapshot = await db.collection('budget').doc(uid)
          .collection('items').get(const GetOptions(source: Source.server));
      final budgets = budgetSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['month'] == month && data['year'] == year &&
            data['isActive'] != false &&
            (onlyType == null || data['type'] == onlyType);
      }).toList();
      if (budgets.isEmpty) return;

      // Fetch once for all budgets. A userId-only query needs no new composite
      // index. This scans user history; large datasets should use monthly totals.
      final snapshot = await db.collection('spending')
          .where('userId', isEqualTo: uid)
          .get(const GetOptions(source: Source.server));
      var total = 0;
      final byType = <int, int>{};
      for (final doc in snapshot.docs) {
        final item = Spending.fromFirebase(doc);
        if (item.money >= 0 || item.month != month || item.year != year) continue;
        final amount = item.money.abs();
        total += amount;
        byType[item.type] = (byType[item.type] ?? 0) + amount;
      }

      final language = _notificationLanguage;
      final translations = await _loadTranslations(language);
      String tr(String key) => translations[key]?.toString() ??
          _budgetFallback[language]![key] ?? key;
      final number = NumberFormat.decimalPattern(
        language == 'en' ? 'en_US' : 'vi_VN',
      );
      String money(int amount) => '${number.format(amount)} ₫';
      final service = NotificationService();
      var showLocal = true;
      try {
        await service.initialize();
      } catch (e) {
        showLocal = false;
        debugPrint('Budget banner unavailable, saving inbox only: $e');
      }

      for (final doc in budgets) {
        if (FirebaseAuth.instance.currentUser?.uid != uid) return;
        try {
          final data = doc.data();
          final type = (data['type'] as num?)?.toInt();
          final limit = (data['limitMoney'] as num?)?.toInt() ?? 0;
          if (type == null || limit <= 0) continue;
          // Keep the existing convention in isOverBudget: type 0 = overall.
          final spent = type == 0
              ? total
              : _budgetCategoryScope(type).fold<int>(
            0,
                (sum, categoryType) => sum + (byType[categoryType] ?? 0),
          );
          if (spent * 100 < limit * 80) continue;
          final level = spent > limit ? 'exceeded'
              : spent == limit ? 'reached' : 'near';
          final rawName = data['typeName']?.toString() ?? '';
          final category = type == 0 ? tr('budget_notification_overall')
              : rawName.isEmpty ? tr('budget_notification_category')
              : translations[rawName]?.toString() ?? rawName;
          final args = <String, String>{
            'category': category,
            'period': '${month.toString().padLeft(2, '0')}/$year',
            'spent': money(spent), 'limit': money(limit),
            'remaining': money(limit > spent ? limit - spent : 0),
            'over': money(spent > limit ? spent - limit : 0),
            'percent': (spent * 100 ~/ limit).toString(),
          };
          String render(String key) {
            var text = tr(key);
            for (final entry in args.entries) {
              text = text.replaceAll('{${entry.key}}', entry.value);
            }
            return text;
          }
          await service.createNotification(
            title: render('budget_notification_${level}_title'),
            body: render('budget_notification_${level}_body'),
            type: level == 'exceeded' ? 'danger' : 'warning',
            deduplicationKey: 'budget_${year}_${month}_${type}_$level',
            showLocal: showLocal,
            data: {
              'source': 'budget', 'budgetId': doc.id, 'month': month,
              'year': year, 'categoryType': type, 'level': level,
              'spent': spent, 'limit': limit, 'language': language,
            },
          );
        } catch (e) {
          debugPrint('Budget alert failed for ${doc.id}: $e');
        }
      }
    } catch (e) {
      // Notifications must not turn a successful save into a reported failure.
      debugPrint('Budget notification check failed: $e');
    }
  }

  // Fallback only when the app JSON does not yet contain these keys.
  static const Map<String, Map<String, String>> _budgetFallback = {
    'vi': {
      'budget_notification_overall': "Tổng chi tiêu",
      'budget_notification_category': "Danh mục chi tiêu",
      'budget_notification_near_title': "{category}: sắp hết ngân sách",
      'budget_notification_near_body': "Tháng {period}: đã chi {spent}/{limit} ({percent}%). Còn {remaining} trong ngân sách.",
      'budget_notification_reached_title': "{category}: đã dùng hết ngân sách",
      'budget_notification_reached_body': "Tháng {period}: đã chi {spent}, bằng hạn mức {limit}. Các khoản chi tiếp theo sẽ vượt ngân sách.",
      'budget_notification_exceeded_title': "{category}: đã vượt ngân sách",
      'budget_notification_exceeded_body': "Tháng {period}: đã chi {spent}/{limit}, vượt {over}. Hãy xem lại các khoản chi còn lại trong tháng.",
    },
    'en': {
      'budget_notification_overall': "Overall spending",
      'budget_notification_category': "Spending category",
      'budget_notification_near_title': "{category}: budget nearly used up",
      'budget_notification_near_body': "For {period}, you have spent {spent} of {limit} ({percent}%). You have {remaining} left.",
      'budget_notification_reached_title': "{category}: budget fully used",
      'budget_notification_reached_body': "For {period}, spending of {spent} has reached your {limit} limit. Further spending will exceed the budget.",
      'budget_notification_exceeded_title': "{category}: budget exceeded",
      'budget_notification_exceeded_body': "For {period}, you have spent {spent} of {limit}, exceeding the budget by {over}. Review your remaining expenses this month.",
    },
  };

  // =====================================================
  // ================= DELETE BUDGET =====================
  // =====================================================

  static Future<void> deleteBudget({
    required int type,
    required int month,
    required int year,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection("budget")
        .doc(uid)
        .collection("items")
        .doc("${year}_${month}_${type}");

    try {
      final docSnap = await ref.get();
      if (!docSnap.exists) return;
      await ref.delete();
    } catch (e) {
      print("Error deleting budget: $e");
    }
  }
  // =====================================================
  // ================= USER ==============================
  // =====================================================

  static Future<void> updateInfo({
    required myuser.User user,
    File? image,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (image != null) {
      user.avatar = await uploadImage(
        folder: "avatar",
        name: "$uid.png",
        image: image,
      );
    }

    final profile = user.toMap()..remove('money');
    if(user.createdAt == null) profile.remove('createdAt');
    await FirebaseFirestore.instance.collection('info').doc(uid).set(profile, SetOptions(merge:true));
  }

  // =====================================================
  // ================= IMAGE =============================
  // =====================================================

  static Future<String> uploadImage({
    required String folder,
    required String name,
    required File image,
  }) async {
    final ref = FirebaseStorage.instance.ref("$folder/$name");
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }
}
