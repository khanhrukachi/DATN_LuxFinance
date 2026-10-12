import 'package:personal_financial_management/core/constants/function/debt_phone_validator.dart';

import 'dart:async';
import 'wallet_firebase.dart';
import 'debt_reminder_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/debt.dart';

/// Separate debt ledger; all cash changes commit atomically with info.money.
class DebtFirebase {
  final FirebaseFirestore db;
  final String uid;
  final FirebaseAuth auth;
  final bool reminders;
  DebtFirebase({FirebaseFirestore? firestore, String? userId, FirebaseAuth? auth, this.reminders=true}) : db = firestore ?? FirebaseFirestore.instance, auth=auth ?? FirebaseAuth.instance, uid = userId ?? (auth ?? FirebaseAuth.instance).currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get contacts => db.collection('debt_books').doc(uid).collection('contacts');
  CollectionReference<Map<String, dynamic>> get items => db.collection('debt_books').doc(uid).collection('items');
  Stream<List<DebtContact>> watchContacts() => contacts.snapshots().map((s) => s.docs.map(DebtContact.fromDoc).toList()..sort((a,b) => a.name.compareTo(b.name)));
  Stream<List<Debt>> watchDebts() => items.snapshots().map((s) => s.docs.map(Debt.fromDoc).toList()..sort((a,b) => b.date.compareTo(a.date)));
  Future<void> saveContact(DebtContact c) async {
    if (c.name.trim().isEmpty) throw StateError('Tên không được trống');
    final phoneError=DebtPhoneValidator.validate(c.phone);
    if(phoneError!=null)throw ArgumentError(phoneError);
    WalletFirebase.requireSession(uid,auth:auth);
    final data=c.toMap()..['phone']=c.phone.trim();
    await contacts.doc(c.id.isEmpty ? null : c.id).set(data);
  }
  Future<void> deleteContact(String id) async {
    // Application-level reference check; see README about simultaneous contact deletion.
    WalletFirebase.requireSession(uid,auth:auth);
    final related = await items.where('contactId', isEqualTo: id).limit(1).get();
    if (related.docs.isNotEmpty) throw StateError('Đối tượng còn khoản nợ, không thể xóa');
    await contacts.doc(id).delete();
  }
  void validate(Debt d) {
    if (d.amount <= 0 || d.amount > 999999999999) throw StateError('Số tiền không hợp lệ');
    if (!['lend','borrow'].contains(d.direction)) throw StateError('Loại nợ không hợp lệ');
    if (d.dueDate != null && d.dueDate!.isBefore(DateTime(d.date.year,d.date.month,d.date.day))) throw StateError('Hạn trả phải từ ngày giao dịch');
    if (d.amount < d.paid) throw StateError('Số tiền nợ không thể nhỏ hơn số đã trả');
  }
  Future<void> saveDebt(Debt d, {bool create = false, bool alreadyInWallet = false}) async {
    validate(d);
    final ref = items.doc(d.id.isEmpty ? null : d.id);
    await db.runTransaction((tx) async {
      final contact = await tx.get(contacts.doc(d.contactId));
      final old = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx, db, uid,auth:auth);
      if (!contact.exists) throw StateError('Đối tượng không tồn tại');
      if (!create && d.id.isNotEmpty && !old.exists) throw StateError('Khoản nợ đã bị xóa');
      if(create && old.exists) {
        final stored=Debt.fromDoc(old);
        if(stored.amount!=d.amount || stored.direction!=d.direction || stored.contactId!=d.contactId || stored.date!=d.date || stored.dueDate!=d.dueDate || stored.note!=d.note || stored.remind!=d.remind || stored.walletTracked!=d.walletTracked) throw StateError('Khoản nợ đã được lưu với thông tin khác. Hãy đóng màn hình và mở lại');
        return; // Same create id: no second wallet delta.
      }
      final current = old.exists ? Debt.fromDoc(old) : null;
      if(current?.walletTracked==true && !d.walletTracked) throw StateError('Khoản đã liên kết ví không thể bỏ liên kết');
      if (current != null && current.revision != d.revision) throw StateError('Dữ liệu đã thay đổi. Hãy mở lại khoản nợ');
      if (current != null && current.payments.isNotEmpty && (current.direction != d.direction || current.contactId != d.contactId)) throw StateError('Đã có thanh toán, không thể đổi đối tượng hoặc loại nợ');
      if (current != null && d.amount < current.paid) throw StateError('Số tiền không thể nhỏ hơn đã trả');
      if (current != null && current.payments.any((p) => p.date.isBefore(DateTime(d.date.year,d.date.month,d.date.day)))) throw StateError('Ngày vay không được sau ngày thanh toán đã ghi');
      final baseline=current?.walletTracked==true ? current!.walletBaseline : alreadyInWallet && d.walletTracked ? Debt.cashImpact(d.direction,d.amount,current?.paid ?? 0) : 0;
      final impact = d.walletTracked ? Debt.cashImpact(d.direction,d.amount,current?.paid ?? 0)-baseline : 0;
      final data = d.toMap();
      data['walletImpact'] = impact;
      data['walletBaseline'] = baseline;
      wallet.apply(impact - (current?.walletImpact ?? 0));
      data['contactName'] = contact.data()!['name'];
      data['payments'] = current?.payments.map((p) => p.toMap()).toList() ?? [];
      data['revision'] = (current?.revision ?? -1) + 1;
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['createdAt'] = current == null ? FieldValue.serverTimestamp() : old.data()!['createdAt'] ?? FieldValue.serverTimestamp();
      tx.set(ref, data);
    });
    if(reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }
  Future<void> addPayment(String debtId, DebtPayment p) async {
    await db.runTransaction((tx) async {
      final ref = items.doc(debtId);
      final snap = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx, db, uid,auth:auth);
      if (!snap.exists) throw StateError('Khoản nợ đã bị xóa');
      final d = Debt.fromDoc(snap);
      final matching=d.payments.where((x) => x.id==p.id).toList();
      if(matching.isNotEmpty) {
        final stored=matching.first;
        if(stored.amount!=p.amount || stored.date!=p.date || stored.note!=p.note) throw StateError('Lần thanh toán này đã lưu. Hãy đóng và xem lại lịch sử');
        return; // Stable retry id: no duplicate payment or wallet delta.
      }
      if (p.amount <= 0 || p.amount > d.remaining) throw StateError('Số tiền trả phải từ 1 đến số còn nợ');
      if (p.date.isBefore(DateTime(d.date.year,d.date.month,d.date.day))) throw StateError('Ngày trả không được trước ngày vay');
      if (d.payments.length >= 500) throw StateError('Khoản nợ đã đạt giới hạn 500 lần thanh toán');
      final impact = d.walletTracked ? Debt.cashImpact(d.direction,d.amount,d.paid+p.amount)-d.walletBaseline : 0;
      wallet.apply(impact-d.walletImpact);
      tx.update(ref, {'walletImpact':impact, 'payments': [...d.payments.map((x) => x.toMap()), p.toMap()], 'revision': d.revision + 1, 'updatedAt': FieldValue.serverTimestamp()});
    });
    if(reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }
  Future<void> removePayment(String debtId, String paymentId) async {
    await db.runTransaction((tx) async {
      final ref = items.doc(debtId);
      final snap = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx, db, uid,auth:auth);
      if (!snap.exists) throw StateError('Khoản nợ đã bị xóa');
      final d = Debt.fromDoc(snap);
      final removed = d.payments.where((p) => p.id == paymentId).toList();
      if (removed.isEmpty) return;
      final impact = d.walletTracked ? Debt.cashImpact(d.direction,d.amount,d.paid-removed.first.amount)-d.walletBaseline : 0;
      wallet.apply(impact-d.walletImpact);
      tx.update(ref, {'walletImpact':impact, 'payments': d.payments.where((p) => p.id != paymentId).map((p) => p.toMap()).toList(), 'revision': d.revision + 1, 'updatedAt': FieldValue.serverTimestamp()});
    });
    if(reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }
  Future<void> setReminderEnabled(String debtId, bool enabled) async {
    WalletFirebase.requireSession(uid,auth:auth);
    await db.runTransaction((tx) async {
      final ref=items.doc(debtId);
      final doc=await tx.get(ref);
      if(!doc.exists)return;
      final d=Debt.fromDoc(doc);
      tx.update(ref,{'remind':enabled,'revision':d.revision+1,
        'walletTracked':d.walletTracked,'walletImpact':d.walletImpact,'walletBaseline':d.walletBaseline,
        'updatedAt':FieldValue.serverTimestamp()});
    });
    if(reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }
  Future<void> deleteDebt(Debt d) async {
    await db.runTransaction((tx) async {
      final ref = items.doc(d.id);
      final s = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx, db, uid,auth:auth);
      if (!s.exists) return;
      if (Debt.fromDoc(s).revision != d.revision) throw StateError('Dữ liệu đã thay đổi. Hãy mở lại trước khi xóa');
      wallet.apply(-Debt.fromDoc(s).walletImpact);
      tx.delete(ref);
    });
    if(reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }
}
