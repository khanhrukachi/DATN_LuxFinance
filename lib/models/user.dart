import 'package:cloud_firestore/cloud_firestore.dart';

const defaultAvatar =
    "https://firebasestorage.googleapis.com/v0/b/facebook-clone-9f92c.appspot.com/o/avatar%2Ftenor.gif?alt=media&token=cfa3c765-47f8-41f9-9eed-07e7c1f3b48e";

class User {
  String name;
  String birthday;
  String avatar;
  bool gender;

  int money;

  String currentAddress;
  String maritalStatus;
  String job;
  String educationLevel;
  int averageMonthlyIncome;

  String lifestyle;
  String riskTolerance;
  List<String> hobbies;

  bool hasCompletedSurvey;
  Timestamp? createdAt;

  User({
    required this.name,
    required this.birthday,
    required this.avatar,
    required this.money,
    this.gender = true,

    this.currentAddress = "",
    this.maritalStatus = "",
    this.job = "",
    this.educationLevel = "",
    this.averageMonthlyIncome = 0,

    this.lifestyle = "",
    this.riskTolerance = "",
    this.hobbies = const [],

    this.hasCompletedSurvey = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    "name": name,
    "birthday": birthday,
    "avatar": avatar,
    "gender": gender,
    "money": money,

    "currentAddress": currentAddress,
    "maritalStatus": maritalStatus,
    "job": job,
    "educationLevel": educationLevel,
    "averageMonthlyIncome": averageMonthlyIncome,

    "lifestyle": lifestyle,
    "riskTolerance": riskTolerance,
    "hobbies": hobbies,

    "hasCompletedSurvey": hasCompletedSurvey,
    "createdAt": createdAt ?? FieldValue.serverTimestamp(),
  };

  factory User.fromFirebase(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    return User(
      name: data["name"] ?? "",
      birthday: data["birthday"] ?? "",
      avatar: data["avatar"] ?? defaultAvatar,
      gender: data["gender"] ?? true,
      money: data["money"] ?? 0,

      currentAddress: data["currentAddress"] ?? "",
      maritalStatus: data["maritalStatus"] ?? "",
      job: data["job"] ?? "",
      educationLevel: data["educationLevel"] ?? "",
      averageMonthlyIncome: data["averageMonthlyIncome"] ?? 0,

      lifestyle: data["lifestyle"] ?? "",
      riskTolerance: data["riskTolerance"] ?? "",
      hobbies: List<String>.from(data["hobbies"] ?? []),

      hasCompletedSurvey: data["hasCompletedSurvey"] ?? false,
      createdAt: data["createdAt"],
    );
  }

  // ================= COPY =================

  User copyWith({
    String? name,
    String? birthday,
    String? avatar,
    bool? gender,
    int? money,

    String? currentAddress,
    String? maritalStatus,
    String? job,
    String? educationLevel,
    int? averageMonthlyIncome,

    String? lifestyle,
    String? riskTolerance,
    List<String>? hobbies,

    bool? hasCompletedSurvey,
  }) {
    return User(
      name: name ?? this.name,
      birthday: birthday ?? this.birthday,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      money: money ?? this.money,

      currentAddress: currentAddress ?? this.currentAddress,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      job: job ?? this.job,
      educationLevel: educationLevel ?? this.educationLevel,
      averageMonthlyIncome:
      averageMonthlyIncome ?? this.averageMonthlyIncome,

      lifestyle: lifestyle ?? this.lifestyle,
      riskTolerance: riskTolerance ?? this.riskTolerance,
      hobbies: hobbies ?? this.hobbies,

      hasCompletedSurvey:
      hasCompletedSurvey ?? this.hasCompletedSurvey,
    );
  }
}