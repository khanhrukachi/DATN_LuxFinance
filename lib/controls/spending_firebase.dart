import 'dart:io';

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
  // ================= BUDGET ============================
  // =====================================================

  static Future<void> addOrUpdateBudget(Budget budget) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection("budget")
        .doc(uid)
        .collection("items")
        .doc("${budget.year}_${budget.month}_${budget.type}");

    await ref.set(budget.toMap(), SetOptions(merge: true));
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

    final ref = FirebaseFirestore.instance
        .collection("budget")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection("items")
        .doc(budget.id);

    await ref.update({
      "limitMoney": newLimit,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

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
