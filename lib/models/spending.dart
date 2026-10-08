import 'package:cloud_firestore/cloud_firestore.dart';

class Spending {
  String? id;

  int money;
  int type;
  String? typeName;
  String? categoryId;
  String? parentId;
  String? parentName;

  String? note;
  DateTime dateTime;
  String? image;
  String? location;
  List<String> friends;

  late int day;
  late int month;
  late int year;
  late int weekday;
  late int hour;
  late bool isExpense;
  late bool isIncome;

  Spending({
    this.id,
    required this.money,
    required this.type,
    required this.dateTime,
    this.note,
    this.image,
    this.typeName,
    this.categoryId,
    this.parentId,
    this.parentName,
    this.location,
    List<String>? friends,
  }) : friends = friends ?? [] {
    day = dateTime.day;
    month = dateTime.month;
    year = dateTime.year;
    weekday = dateTime.weekday;
    hour = dateTime.hour;

    isExpense = money < 0;
    isIncome = money > 0;
  }


  Map<String, dynamic> toMap() => {
    "money": money,
    "type": type,
    "typeName": typeName,
    "categoryId": categoryId,
    "parentId": parentId,
    "parentName": parentName,
    "note": note,
    "date": Timestamp.fromDate(dateTime),
    "image": image,
    "location": location,
    "friends": friends,
  };

  factory Spending.fromFirebase(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final date =
        (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Spending(
      id: snapshot.id,
      money: (data['money'] ?? 0).toInt(),
      type: data['type'] ?? 0,
      typeName: data['typeName'],
      categoryId: data['categoryId'],
      parentId: data['parentId'],
      parentName: data['parentName'],
      dateTime: date,
      note: data['note'],
      image: data['image'],
      location: data['location'],
      friends: (data['friends'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    "amount": money.abs(),
    "label": isExpense ? "expense" : "income",
    "category": typeName ?? "",
    "category_id": categoryId ?? "",
    "parent_id": parentId ?? "",
    "parent": parentName ?? "",
    "type_code": type,
    "day": day,
    "month": month,
    "year": year,
    "weekday": weekday,
    "hour": hour,
    "location": location ?? "",
  };

  Spending copyWith({
    int? money,
    int? type,
    DateTime? dateTime,
    String? note,
    String? image,
    String? typeName,
    String? categoryId,
    String? parentId,
    String? parentName,
    String? location,
    List<String>? friends,
  }) {
    return Spending(
      id: id,
      money: money ?? this.money,
      type: type ?? this.type,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      image: image ?? this.image,
      typeName: typeName ?? this.typeName,
      categoryId: categoryId ?? this.categoryId,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
      location: location ?? this.location,
      friends: friends ?? this.friends,
    );
  }
}
