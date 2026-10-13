import 'package:personal_financial_management/setting/localization/service_localizations.dart';
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

  DebtFirebase({
    FirebaseFirestore? firestore,
    String? userId,
    FirebaseAuth? auth,
    this.reminders = true,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance,
       uid =
           userId ??
           ((auth ?? FirebaseAuth.instance).currentUser?.uid ??
               (throw ServiceException('service_login_required')));

  CollectionReference<Map<String, dynamic>> get contacts =>
      db.collection('debt_books').doc(uid).collection('contacts');

  CollectionReference<Map<String, dynamic>> get items =>
      db.collection('debt_books').doc(uid).collection('items');

  Stream<List<DebtContact>> watchContacts() => contacts.snapshots().map(
    (s) =>
        s.docs.map(DebtContact.fromDoc).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  Stream<List<Debt>> watchDebts() => items.snapshots().map(
    (s) =>
        s.docs.map(Debt.fromDoc).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
  );

  Future<void> saveContact(DebtContact c) async {
    await ServiceLocalizations.initialize();
    if (c.name.trim().isEmpty) {
      throw ServiceException('service_contact_name_required');
    }
    final phoneError = DebtPhoneValidator.validate(c.phone);
    if (phoneError != null) {
      throw ServiceArgumentException(
        phoneError == DebtPhoneValidator.digitsError
            ? 'service_phone_digits'
            : 'service_phone_format',
      );
    }
    WalletFirebase.requireSession(uid, auth: auth);
    final data = c.toMap()..['phone'] = c.phone.trim();
    await contacts.doc(c.id.isEmpty ? null : c.id).set(data);
  }

  Future<void> deleteContact(String id) async {
    await ServiceLocalizations.initialize();
    // Application-level reference check; see README about simultaneous contact deletion.
    WalletFirebase.requireSession(uid, auth: auth);
    final related = await items
        .where('contactId', isEqualTo: id)
        .limit(1)
        .get();
    if (related.docs.isNotEmpty) {
      throw ServiceException('service_contact_has_debts');
    }
    await contacts.doc(id).delete();
  }

  void validate(Debt d) {
    if (d.amount <= 0 || d.amount > 999999999999) {
      throw ServiceException('service_amount_invalid');
    }
    if (!['lend', 'borrow'].contains(d.direction)) {
      throw ServiceException('service_debt_direction_invalid');
    }
    if (d.dueDate != null &&
        d.dueDate!.isBefore(DateTime(d.date.year, d.date.month, d.date.day))) {
      throw ServiceException('service_due_before_date');
    }
    if (d.amount < d.paid) throw ServiceException('service_amount_below_paid');
  }

  Future<void> saveDebt(
    Debt d, {
    bool create = false,
    bool alreadyInWallet = false,
  }) async {
    await ServiceLocalizations.initialize();
    validate(d);
    final ref = items.doc(d.id.isEmpty ? null : d.id);
    await db.runTransaction((tx) async {
      final contact = await tx.get(contacts.doc(d.contactId));
      final old = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx, db, uid, auth: auth);
      if (!contact.exists) throw ServiceException('service_contact_missing');
      if (!create && d.id.isNotEmpty && !old.exists) {
        throw ServiceException('service_debt_deleted');
      }
      if (create && old.exists) {
        final stored = Debt.fromDoc(old);
        if (stored.amount != d.amount ||
            stored.direction != d.direction ||
            stored.contactId != d.contactId ||
            stored.date != d.date ||
            stored.dueDate != d.dueDate ||
            stored.note != d.note ||
            stored.remind != d.remind ||
            stored.walletTracked != d.walletTracked) {
          throw ServiceException('service_debt_create_conflict');
        }
        return; // Same create id: no second wallet delta.
      }
      final current = old.exists ? Debt.fromDoc(old) : null;
      if (current?.walletTracked == true && !d.walletTracked) {
        throw ServiceException('service_wallet_unlink_forbidden');
      }
      if (current != null && current.revision != d.revision) {
        throw ServiceException('service_debt_changed');
      }
      if (current != null &&
          current.payments.isNotEmpty &&
          (current.direction != d.direction ||
              current.contactId != d.contactId)) {
        throw ServiceException('service_paid_contact_locked');
      }
      if (current != null && d.amount < current.paid) {
        throw ServiceException('service_amount_below_paid');
      }
      if (current != null &&
          current.payments.any(
            (p) => p.date.isBefore(
              DateTime(d.date.year, d.date.month, d.date.day),
            ),
          )) {
        throw ServiceException('service_debt_date_after_payment');
      }
      final baseline = current?.walletTracked == true
          ? current!.walletBaseline
          : alreadyInWallet && d.walletTracked
          ? Debt.cashImpact(d.direction, d.amount, current?.paid ?? 0)
          : 0;
      final impact = d.walletTracked
          ? Debt.cashImpact(d.direction, d.amount, current?.paid ?? 0) -
                baseline
          : 0;
      final data = d.toMap();
      data['walletImpact'] = impact;
      data['walletBaseline'] = baseline;
      wallet.apply(impact - (current?.walletImpact ?? 0));
      data['contactName'] = contact.data()!['name'];
      data['payments'] = current?.payments.map((p) => p.toMap()).toList() ?? [];
      data['revision'] = (current?.revision ?? -1) + 1;
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['createdAt'] = current == null
          ? FieldValue.serverTimestamp()
          : old.data()!['createdAt'] ?? FieldValue.serverTimestamp();
      tx.set(ref, data);
    });
    if (reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }

  Future<void> addPayment(String debtId, DebtPayment p) async {
    await ServiceLocalizations.initialize();
    await db.runTransaction((tx) async {
      final ref = items.doc(debtId);
      final snap = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx, db, uid, auth: auth);
      if (!snap.exists) throw ServiceException('service_debt_deleted');
      final d = Debt.fromDoc(snap);
      final matching = d.payments.where((x) => x.id == p.id).toList();
      if (matching.isNotEmpty) {
        final stored = matching.first;
        if (stored.amount != p.amount ||
            stored.date != p.date ||
            stored.note != p.note) {
          throw ServiceException('service_payment_duplicate_conflict');
        }
        return; // Stable retry id: no duplicate payment or wallet delta.
      }
      if (p.amount <= 0 || p.amount > d.remaining) {
        throw ServiceException('service_payment_amount_invalid');
      }
      if (p.date.isBefore(DateTime(d.date.year, d.date.month, d.date.day))) {
        throw ServiceException('service_payment_date_before_debt');
      }
      if (d.payments.length >= 500) {
        throw ServiceException('service_payment_limit');
      }
      final impact = d.walletTracked
          ? Debt.cashImpact(d.direction, d.amount, d.paid + p.amount) -
                d.walletBaseline
          : 0;
      wallet.apply(impact - d.walletImpact);
      tx.update(ref, {
        'walletImpact': impact,
        'payments': [...d.payments.map((x) => x.toMap()), p.toMap()],
        'revision': d.revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }

  Future<void> removePayment(String debtId, String paymentId) async {
    await ServiceLocalizations.initialize();
    await db.runTransaction((tx) async {
      final ref = items.doc(debtId);
      final snap = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx, db, uid, auth: auth);
      if (!snap.exists) throw ServiceException('service_debt_deleted');
      final d = Debt.fromDoc(snap);
      final removed = d.payments.where((p) => p.id == paymentId).toList();
      if (removed.isEmpty) return;
      final impact = d.walletTracked
          ? Debt.cashImpact(
                  d.direction,
                  d.amount,
                  d.paid - removed.first.amount,
                ) -
                d.walletBaseline
          : 0;
      wallet.apply(impact - d.walletImpact);
      tx.update(ref, {
        'walletImpact': impact,
        'payments': d.payments
            .where((p) => p.id != paymentId)
            .map((p) => p.toMap())
            .toList(),
        'revision': d.revision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }

  Future<void> setReminderEnabled(String debtId, bool enabled) async {
    await ServiceLocalizations.initialize();
    WalletFirebase.requireSession(uid, auth: auth);
    await db.runTransaction((tx) async {
      final ref = items.doc(debtId);
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final d = Debt.fromDoc(doc);
      tx.update(ref, {
        'remind': enabled,
        'revision': d.revision + 1,
        'walletTracked': d.walletTracked,
        'walletImpact': d.walletImpact,
        'walletBaseline': d.walletBaseline,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }

  Future<void> deleteDebt(Debt d) async {
    await ServiceLocalizations.initialize();
    await db.runTransaction((tx) async {
      final ref = items.doc(d.id);
      final s = await tx.get(ref);
      final wallet = await WalletFirebase.read(tx, db, uid, auth: auth);
      if (!s.exists) return;
      if (Debt.fromDoc(s).revision != d.revision) {
        throw ServiceException('service_debt_delete_changed');
      }
      wallet.apply(-Debt.fromDoc(s).walletImpact);
      tx.delete(ref);
    });
    if (reminders) unawaited(DebtReminderService.instance.refreshSafely(uid));
  }
}
