import 'package:personal_financial_management/setting/localization/service_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// info.money is authoritative. wallet/MM_yyyy is a compatible snapshot of
/// the current balance when a mutation occurs, NOT a reconstructed month-end.
class WalletFirebase {
  static void requireSession(String uid, {FirebaseAuth? auth}) {
    if ((auth ?? FirebaseAuth.instance).currentUser?.uid != uid) {
      throw ServiceException('service_session_changed');
    }
  }

  static Future<WalletTransaction> read(
    Transaction tx,
    FirebaseFirestore db,
    String uid, {
    FirebaseAuth? auth,
  }) async {
    await ServiceLocalizations.initialize();
    requireSession(uid, auth: auth);
    final user = db.collection('info').doc(uid);
    final wallet = db.collection('wallet').doc(uid);
    final snap = await tx.get(user);
    if (!snap.exists) throw ServiceException('service_user_missing');
    final raw = snap.data()?['money'];
    if (raw != null && raw is! num) {
      throw ServiceException('service_wallet_invalid');
    }
    return WalletTransaction(
      tx,
      user,
      wallet,
      (raw as num?)?.toInt() ?? 0,
      DateFormat('MM_yyyy').format(DateTime.now()),
      uid,
      auth ?? FirebaseAuth.instance,
    );
  }

  static Stream<int> watch(String uid) => FirebaseFirestore.instance
      .collection('info')
      .doc(uid)
      .snapshots()
      .map((s) => (s.data()?['money'] as num?)?.toInt() ?? 0);
}

class WalletTransaction {
  final Transaction tx;
  final DocumentReference<Map<String, dynamic>> user, wallet;
  final int balance;
  final String period, uid;
  final FirebaseAuth auth;

  WalletTransaction(
    this.tx,
    this.user,
    this.wallet,
    this.balance,
    this.period,
    this.uid,
    this.auth,
  );

  void apply(int delta) {
    WalletFirebase.requireSession(uid, auth: auth);
    if (delta == 0) return;
    final value = balance + delta;
    tx.update(user, {'money': value});
    tx.set(wallet, {period: value}, SetOptions(merge: true));
  }
}
