import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  String? id;
  int limitMoney;
  int type;
  String? typeName;
  int month;
  int year;
  bool isActive;
  DateTime createdAt;

  Budget({
    this.id,
    required this.limitMoney,
    required this.type,
    required this.month,
    required this.year,
    this.typeName,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    "limitMoney": limitMoney,
    "type": type,
    "typeName": typeName,
    "month": month,
    "year": year,
    "isActive": isActive,
    "createdAt": Timestamp.fromDate(createdAt),
  };

  factory Budget.fromFirebase(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};

    return Budget(
      id: snapshot.id,
      limitMoney: (data['limitMoney'] ?? 0).toInt(),
      type: data['type'] ?? 0,
      typeName: data['typeName'],
      month: data['month'] ?? DateTime.now().month,
      year: data['year'] ?? DateTime.now().year,
      isActive: data['isActive'] ?? true,
      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    "budget_limit": limitMoney,
    "category": typeName ?? "",
    "type_code": type,
    "month": month,
    "year": year,
    "is_active": isActive,
  };

  Budget copyWith({
    int? limitMoney,
    int? type,
    String? typeName,
    int? month,
    int? year,
    bool? isActive,
  }) {
    return Budget(
      id: id,
      limitMoney: limitMoney ?? this.limitMoney,
      type: type ?? this.type,
      typeName: typeName ?? this.typeName,
      month: month ?? this.month,
      year: year ?? this.year,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
