import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/models/spending.dart';
import 'package:personal_financial_management/models/user.dart' as myuser;

class SpendingFirebase {
  // =====================================================
  // ================= MONEY CORE ========================
  // =====================================================

  static Future<void> _updateCurrentMoney(int delta) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final monthKey = DateFormat("MM_yyyy").format(DateTime.now());

    final walletRef =
    FirebaseFirestore.instance.collection("wallet").doc(uid);
    final userRef =
    FirebaseFirestore.instance.collection("info").doc(uid);

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

      tx.update(userRef, {'money': newMoney});

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

    final spendingRef =
    FirebaseFirestore.instance.collection("spending").doc();
    final dataRef =
    FirebaseFirestore.instance.collection("data").doc(uid);

    // upload image
    if (spending.image != null) {
      spending.image = await uploadImage(
        folder: "spending",
        name: "${spendingRef.id}.png",
        image: File(spending.image!),
      );
    }

    await spendingRef.set(spending.toMap());

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

    // 🔥 update money
    await _updateCurrentMoney(spending.money.toInt());
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
    final dataRef =
    FirebaseFirestore.instance.collection("data").doc(uid);

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

    await spendingRef.update(spending.toMap());

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

    final int delta = spending.money.toInt() - oldMoney;
    await _updateCurrentMoney(delta);
  }

  // =====================================================
  // ================= DELETE SPENDING ===================
  // =====================================================

  static Future<void> deleteSpending(Spending spending) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dataRef =
    FirebaseFirestore.instance.collection("data").doc(uid);

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

    await _updateCurrentMoney(-spending.money.toInt());
  }

  static Future<List<Spending>> getSpendingList(List<String> ids) async {
    List<Spending> list = [];

    for (final id in ids) {
      final doc = await FirebaseFirestore.instance
          .collection("spending")
          .doc(id)
          .get();

      if (doc.exists && doc.data() != null) {
        list.add(Spending.fromFirebase(doc));
      }
    }

    return list;
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
        .update(user.toMap());
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
