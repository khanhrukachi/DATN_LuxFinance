import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/features/main/main_page.dart';

import '../../../../core/constants/function/get_survey_data.dart';
import '../../../../core/constants/function/loading_animation.dart';
import '../../../../models/user.dart' as myuser;
import '../../../../setting/localization/app_localizations.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final birthdayCtrl = TextEditingController();
  final avatarCtrl = TextEditingController();
  List<String> selectedHobbies = [];

  bool gender = true;

  String province = SurveyData.provinces.first;
  String job = SurveyData.jobs.first;
  String maritalStatus = "single";
  String lifestyle = "balanced";
  String riskTolerance = "medium";
  String education = SurveyData.educationLevels.first;
  String incomeRange = SurveyData.incomeRanges.first;

  final List<String> maritalOptions = ["single", "married", "other"];
  final List<String> lifestyleOptions = ["saving", "balanced", "enjoy"];
  final List<String> riskOptions = ["low", "medium", "high"];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }


  Future<void> _loadUserData() async {
    loadingAnimation(context);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance.collection("info").doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        nameCtrl.text = data['name'] ?? '';
        birthdayCtrl.text = data['birthday'] ?? '';
        avatarCtrl.text = data['avatar'] ?? myuser.defaultAvatar;
        gender = data['gender'] ?? true;

        province = SurveyData.provinces.contains(data['currentAddress'])
            ? data['currentAddress']
            : SurveyData.provinces.first;

        maritalStatus = maritalOptions.contains(data['maritalStatus'])
            ? data['maritalStatus']
            : "single";

        job = SurveyData.jobs.contains(data['job'])
            ? data['job']
            : SurveyData.jobs.first;

        education = SurveyData.educationLevels.contains(data['educationLevel'])
            ? data['educationLevel']
            : SurveyData.educationLevels.first;

        incomeRange = SurveyData.incomeRanges.contains(data['incomeRange'])
            ? data['incomeRange']
            : SurveyData.incomeRanges.first;

        lifestyle = lifestyleOptions.contains(data['lifestyle'])
            ? data['lifestyle']
            : "balanced";

        riskTolerance = riskOptions.contains(data['riskTolerance'])
            ? data['riskTolerance']
            : "medium";

        selectedHobbies =
            (data['hobbies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ?? [];

      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading data: $e")),
      );
    } finally {
      Navigator.of(context).pop();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.translate("update_profile")),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(t.translate("personal_info")),
              _card([
                _input(nameCtrl, t.translate("full_name"), t),
                _datePicker(t),
                _genderPicker(t),
              ]),
              _section(t.translate("social_info")),
              _card([
                buildDropdown(
                    t,
                    t.translate("current_address"),
                    province,
                    SurveyData.provinces,
                        (v) => setState(() => province = v)),
                buildDropdown(
                    t,
                    t.translate("marital_status"),
                    maritalStatus,
                    maritalOptions,
                        (v) => setState(() => maritalStatus = v),
                    translateValues: true),
              ]),
              _section(t.translate("job_education")),
              _card([
                buildDropdown(
                    t, t.translate("job"), job, SurveyData.jobs,
                        (v) => setState(() => job = v)),
                buildDropdown(
                    t,
                    t.translate("education"),
                    education,
                    SurveyData.educationLevels,
                        (v) => setState(() => education = v)),
                buildDropdown(
                    t,
                    t.translate("income_range"),
                    incomeRange,
                    SurveyData.incomeRanges,
                        (v) => setState(() => incomeRange = v)),
              ]),
              _section(t.translate("financial_behavior")),
              _card([
                buildDropdown(
                    t,
                    t.translate("lifestyle"),
                    lifestyle,
                    lifestyleOptions,
                        (v) => setState(() => lifestyle = v),
                    translateValues: true),
                buildDropdown(
                    t,
                    t.translate("risk_tolerance"),
                    riskTolerance,
                    riskOptions,
                        (v) => setState(() => riskTolerance = v),
                    translateValues: true),
                _buildHobbySelector(t),
              ]),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  t.translate("confirm"),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI Helpers =================
  Widget _section(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _card(List<Widget> children) => Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );

  Widget _input(TextEditingController ctrl, String label, AppLocalizations t,
      {bool required = true, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            validator: (v) => required && (v == null || v.isEmpty)
                ? t.translate("required_field")
                : null,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHobbySelector(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate("hobbies"),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showHobbyDialog(t),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: selectedHobbies.isEmpty
                        ? Text(
                      t.translate("choose_hobbies"),
                      style: TextStyle(color: Colors.grey.shade900),
                      overflow: TextOverflow.ellipsis,
                    )
                        : Text(
                      selectedHobbies.join(", "),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHobbyDialog(AppLocalizations t) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      t.translate("choose_hobbies"),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: SurveyData.hobbies.length,
                        itemBuilder: (_, index) {
                          final hobby = SurveyData.hobbies[index];
                          final selected = selectedHobbies.contains(hobby);

                          return CheckboxListTile(
                            value: selected,
                            title: Text(hobby),
                            onChanged: (checked) {
                              if (checked == true &&
                                  selectedHobbies.length >= 5) return;

                              setDialogState(() {
                                if (checked == true) {
                                  selectedHobbies.add(hobby);
                                } else {
                                  selectedHobbies.remove(hobby);
                                }
                              });

                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.translate("confirm")),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _genderPicker(AppLocalizations t) {
    return Row(
      children: [
        Text("${t.translate("gender")}: "),
        const SizedBox(width: 12),
        Radio(
          value: true,
          groupValue: gender,
          onChanged: (_) => setState(() => gender = true),
        ),
        Text(t.translate("male")),
        const SizedBox(width: 16),
        Radio(
          value: false,
          groupValue: gender,
          onChanged: (_) => setState(() => gender = false),
        ),
        Text(t.translate("female")),
      ],
    );
  }

  Widget _datePicker(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: birthdayCtrl,
        readOnly: true,
        decoration: InputDecoration(
          labelText: t.translate("birthday"),
          border: const OutlineInputBorder(),
        ),
        validator: (v) =>
        (v == null || v.isEmpty) ? t.translate("choose_birthday") : null,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
            initialDate: birthdayCtrl.text.isNotEmpty
                ? DateFormat("dd/MM/yyyy").parse(birthdayCtrl.text)
                : DateTime(2000),
          );
          if (date != null) {
            birthdayCtrl.text = DateFormat("dd/MM/yyyy").format(date);
          }
        },
      ),
    );
  }

  Widget buildDropdown(
      AppLocalizations t,
      String label,
      String value,
      List<String> options,
      Function(String) onChanged, {
        bool translateValues = false,
      }) {
    final safeValue = options.contains(value) ? value : options.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withOpacity(0.3),
                builder: (_) => Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.5,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text("${t.translate("choose")} $label",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          Expanded(
                            child: ListView.builder(
                              itemCount: options.length,
                              itemBuilder: (_, index) {
                                final item = options[index];
                                return ListTile(
                                  title: Text(
                                      translateValues ? t.translate(item) : item),
                                  trailing: item == safeValue
                                      ? const Icon(Icons.check, color: Colors.blue)
                                      : null,
                                  onTap: () {
                                    onChanged(item);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(translateValues
                          ? t.translate(safeValue)
                          : safeValue)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    loadingAnimation(context);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final incomeValue = SurveyData.incomeToValue(incomeRange);

      final user = myuser.User(
        name: nameCtrl.text,
        birthday: birthdayCtrl.text,
        avatar: avatarCtrl.text,
        money: 0,
        gender: gender,
        currentAddress: province,
        maritalStatus: maritalStatus,
        job: job,
        educationLevel: education,
        averageMonthlyIncome: incomeValue,
        lifestyle: lifestyle,
        riskTolerance: riskTolerance,
        hobbies: selectedHobbies,
      );

      await FirebaseFirestore.instance.collection("info").doc(uid).set({
        ...user.toMap(),
        "incomeRange": incomeRange,
        "hasCompletedSurvey": true,
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainPage()),
            (route) => false,
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
