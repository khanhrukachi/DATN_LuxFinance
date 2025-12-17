import 'package:cloud_firestore/cloud_firestore.dart';

const defaultAvatar =
    "https://firebasestorage.googleapis.com/v0/b/facebook-clone-9f92c.appspot.com/o/avatar%2Ftenor.gif?alt=media&token=cfa3c765-47f8-41f9-9eed-07e7c1f3b48e";

class User {
  String name;
  String birthday;
  String avatar;
  bool gender;
  int money;

  User(
      {required this.name,
      required this.birthday,
      required this.avatar,
      required this.money,
      this.gender = true});

  Map<String, dynamic> toMap() => {
        "name": name,
        "birthday": birthday,
        "avatar": avatar,
        "gender": gender,
        "money": money
      };

  factory User.fromFirebase(DocumentSnapshot snapshot) {
    var data = snapshot.data() as Map<String, dynamic>;
    return User(
      name: data["name"],
      birthday: data["birthday"],
      avatar: data["avatar"],
      money: data["money"],
      gender: data['gender'] as bool,
    );
  }

  User copyWith(
      {String? name,
      String? birthday,
      String? avatar,
      bool? gender,
      int? money}) {
    return User(
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
      avatar: avatar ?? defaultAvatar,
      money: money ?? this.money,
      gender: gender ?? this.gender,
    );
  }
}
