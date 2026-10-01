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

class SpendingFirebase {
  // =====================================================
  // ================= MONEY CORE ========================
  // =====================================================

  static Future<void> _updateCurrentMoney(int delta) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final monthKey = DateFormat("MM_yyyy").format(DateTime.now());

    final walletRef = FirebaseFirestore.instance.collection("wallet").doc(uid);
    final userRef = FirebaseFirestore.instance.collection("info").doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final walletSnap = await tx.get(walletRef);
      final userSnap = await tx.get(userRef);

      int currentMoney = 0;

      if (userSnap.exists && userSnap.data() != null) {
        final raw = userSnap.data()!['money'];
        if (raw is num) {
          currentMoney = raw.toInt();
        }
      }

      final int newMoney = currentMoney + delta;

      tx.set(userRef, {'money': newMoney}, SetOptions(merge: true));

      Map<String, dynamic> walletData = {};
      if (walletSnap.exists && walletSnap.data() != null) {
        walletData = Map<String, dynamic>.from(walletSnap.data()!);
      }

      walletData[monthKey] = newMoney;
      tx.set(walletRef, walletData);
    });
  }

  // =====================================================
  // ================= ADD SPENDING ======================
  // =====================================================

  static Future<void> addSpending(Spending spending) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final spendingRef = FirebaseFirestore.instance.collection("spending").doc();
    final dataRef = FirebaseFirestore.instance.collection("data").doc(uid);

    if (spending.image != null) {
      spending.image = await uploadImage(
        folder: "spending",
        name: "${spendingRef.id}.png",
        image: File(spending.image!),
      );
    }

    await spendingRef.set({
      ...spending.toMap(),
      "userId": uid,
    });

    final key = DateFormat("MM_yyyy").format(spending.dateTime);
    final snap = await dataRef.get();

    List<String> ids = [];
    if (snap.exists && snap.data() != null) {
      final raw = snap.data()![key];
      if (raw is List) {
        ids = List<String>.from(raw);
      }
    }

    ids.add(spendingRef.id);
    await dataRef.set({key: ids}, SetOptions(merge: true));

    await _updateCurrentMoney(spending.money);
    await _checkBudgetNotificationsSafely(
      uid: uid, month: spending.dateTime.month, year: spending.dateTime.year,
    );
  }

  // =====================================================
  // ================= UPDATE SPENDING ===================
  // =====================================================

  static Future<void> updateSpending(
      Spending spending,
      DateTime oldDay,
      File? image,
      bool deleteImage,
      ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final spendingRef =
    FirebaseFirestore.instance.collection("spending").doc(spending.id);
    final dataRef = FirebaseFirestore.instance.collection("data").doc(uid);

    final oldSnap = await spendingRef.get();
    int oldMoney = 0;
    if (oldSnap.exists && oldSnap.data() != null) {
      final raw = oldSnap.data()!['money'];
      if (raw is num) {
        oldMoney = raw.toInt();
      }
    }

    if (image != null) {
      spending.image = await uploadImage(
        folder: "spending",
        name: "${spending.id}.png",
        image: image,
      );
    } else if (deleteImage && spending.image != null) {
      await FirebaseStorage.instance
          .ref("spending/${spending.id}.png")
          .delete();
      spending.image = null;
    }

    await spendingRef.update({
      ...spending.toMap(),
      "userId": uid,
    });

    final oldKey = DateFormat("MM_yyyy").format(oldDay);
    final newKey = DateFormat("MM_yyyy").format(spending.dateTime);

    if (oldKey != newKey) {
      final snap = await dataRef.get();
      if (snap.exists && snap.data() != null) {
        final data = Map<String, dynamic>.from(snap.data()!);

        if (data[oldKey] is List) {
          final list = List<String>.from(data[oldKey]);
          list.remove(spending.id);
          data[oldKey] = list;
        }

        final newList =
        data[newKey] is List ? List<String>.from(data[newKey]) : [];
        newList.add(spending.id!);
        data[newKey] = newList;

        await dataRef.set(data);
      }
    }

    final int delta = spending.money - oldMoney;
    await _updateCurrentMoney(delta);
    await _checkBudgetNotificationsSafely(
      uid: uid, month: spending.dateTime.month, year: spending.dateTime.year,
    );
  }

  // =====================================================
  // ================= DELETE SPENDING ===================
  // =====================================================

  static Future<void> deleteSpending(Spending spending) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dataRef = FirebaseFirestore.instance.collection("data").doc(uid);

    final key = DateFormat("MM_yyyy").format(spending.dateTime);

    final snap = await dataRef.get();
    if (snap.exists && snap.data() != null && snap.data()![key] is List) {
      final list = List<String>.from(snap.data()![key]);
      list.remove(spending.id);
      await dataRef.update({key: list});
    }

    if (spending.image != null) {
      await FirebaseStorage.instance
          .ref("spending/${spending.id}.png")
          .delete();
    }

    await FirebaseFirestore.instance
        .collection("spending")
        .doc(spending.id)
        .delete();

    await _updateCurrentMoney(-spending.money);
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

    if (type != null) {
      query = query.where("type", isEqualTo: type);
    }

    final snap = await query.get();

    int total = 0;
    for (var doc in snap.docs) {
      final spending = Spending.fromFirebase(doc);
      if (spending.month == month && spending.year == year) {
        total += spending.money.abs();
      }
    }
    return total;
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
          final spent = type == 0 ? total : (byType[type] ?? 0);
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

    await FirebaseFirestore.instance
        .collection("info")
        .doc(uid)
        .set(user.toMap(), SetOptions(merge: true));
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
