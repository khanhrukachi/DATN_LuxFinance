import 'package:cloud_firestore/cloud_firestore.dart';

class DebtContact {
  final String id, name, phone, role, note;
  const DebtContact({required this.id, required this.name, this.phone = '', this.role = 'person', this.note = ''});
  factory DebtContact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DebtContact(id: doc.id, name: d['name'] as String, phone: d['phone'] as String? ?? '', role: d['role'] as String? ?? 'person', note: d['note'] as String? ?? '');
  }
  Map<String, dynamic> toMap() => {'name': name, 'phone': phone, 'role': role, 'note': note};
}
class DebtPayment {
  final String id, note;
  final int amount;
  final DateTime date;
  const DebtPayment({required this.id, required this.amount, required this.date, this.note = ''});
  factory DebtPayment.fromMap(Map<String, dynamic> d) => DebtPayment(id: d['id'] as String, amount: (d['amount'] as num).toInt(), date: (d['date'] as Timestamp).toDate(), note: d['note'] as String? ?? '');
  Map<String, dynamic> toMap() => {'id': id, 'amount': amount, 'date': Timestamp.fromDate(date), 'note': note};
}
class Debt {
  final String id, contactId, contactName, direction, note;
  final int amount, revision;
  final DateTime date;
  final DateTime? dueDate;
  final bool remind, walletTracked;
  final int walletImpact, walletBaseline;
  final List<DebtPayment> payments;
  const Debt({required this.id, required this.contactId, required this.contactName, required this.direction, required this.amount, required this.date, this.dueDate, this.remind = true, this.note = '', this.payments = const [], this.revision = 0, this.walletTracked = true, this.walletImpact = 0, this.walletBaseline = 0});
  static int cashImpact(String direction, int amount, int paid) => direction == 'borrow' ? amount - paid : paid - amount;
  String get categoryId => direction=='borrow' ? 'borrow' : 'loan';
  String get paymentCategoryId => direction=='borrow' ? 'pay' : 'debt_collection';
  int get paid => payments.fold(0, (sum, p) => sum + p.amount);
  int get remaining => amount - paid;
  String get status => remaining == 0 ? 'paid' : paid > 0 ? 'partial' : 'unpaid';
  bool get overdue {
    final now = DateTime.now();
    return remaining > 0 && dueDate != null && dueDate!.isBefore(DateTime(now.year, now.month, now.day));
  }
  factory Debt.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Debt(id: doc.id, contactId: d['contactId'] as String, contactName: d['contactName'] as String, direction: d['direction'] as String, amount: (d['amount'] as num).toInt(), date: (d['date'] as Timestamp).toDate(), dueDate: (d['dueDate'] as Timestamp?)?.toDate(), remind: d['remind'] as bool? ?? true, walletTracked: d['walletTracked'] as bool? ?? false, walletImpact: (d['walletImpact'] as num?)?.toInt() ?? 0, walletBaseline: (d['walletBaseline'] as num?)?.toInt() ?? 0, note: d['note'] as String? ?? '', revision: (d['revision'] as num?)?.toInt() ?? 0, payments: (d['payments'] as List? ?? []).map((p) => DebtPayment.fromMap(Map<String, dynamic>.from(p as Map))).toList());
  }
  Map<String, dynamic> toMap() => {'contactId': contactId, 'contactName': contactName, 'categoryId':categoryId, 'direction': direction, 'amount': amount, 'date': Timestamp.fromDate(date), 'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!), 'remind': remind, 'note': note, 'payments': payments.map((p) => p.toMap()).toList(), 'revision': revision, 'walletTracked': walletTracked, 'walletImpact': walletImpact, 'walletBaseline': walletBaseline};
}
