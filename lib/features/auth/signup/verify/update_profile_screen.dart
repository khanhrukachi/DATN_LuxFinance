import 'package:personal_financial_management/features/auth/widget/auth_style.dart';
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


  @override
  void dispose() {
    nameCtrl.dispose(); birthdayCtrl.dispose(); avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    loadingAnimation(context);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance.collection("info").doc(uid).get();

      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading data: $e")),
      );
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: AuthSurface(child: Scaffold(
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
              AuthButton(text: t.translate('confirm'), onPressed: _submit),
              const SizedBox(height: 16),
            ],
          ),
        ),
      )),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(
          gradient: AuthStyle.gradient, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w700, color: AuthStyle.text(context)))),
    ]),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: AuthStyle.decoration(context), padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _input(TextEditingController ctrl, String label, AppLocalizations t,
      {bool required = true, String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(controller: ctrl,
        validator: (v) => required && (v == null || v.trim().isEmpty)
            ? t.translate('required_field') : null,
        decoration: AuthStyle.input(context, hint ?? label, icon: Icons.person_outline_rounded)
            .copyWith(labelText: label)),
  );

  Widget _selection(String label, String value, VoidCallback onTap,
      {IconData icon = Icons.expand_more_rounded}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, color: AuthStyle.muted(context), fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Material(color: AuthStyle.background(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AuthStyle.teal.withOpacity(.2))), clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(children: [
                  Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: AuthStyle.text(context)))),
                  const SizedBox(width: 8), Icon(icon, color: AuthStyle.accent(context), size: 22),
                ]))),
      ),
    ]),
  );

  Widget _buildHobbySelector(AppLocalizations t) => _selection(
      t.translate('hobbies'), selectedHobbies.isEmpty ? t.translate('choose_hobbies') : selectedHobbies.join(', '),
          () => _showHobbyDialog(t), icon: Icons.interests_outlined);

  Widget _dialog(String title, Widget list, {Widget? footer}) => Dialog(
    backgroundColor: AuthStyle.card(context), surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    clipBehavior: Clip.antiAlias, insetPadding: const EdgeInsets.all(20),
    child: SizedBox(width: 440, height: MediaQuery.of(context).size.height * .6,
        child: Padding(padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AuthStyle.text(context))),
              const SizedBox(height: 12),
              Expanded(child: list),
              if (footer != null) ...[const SizedBox(height: 12), footer],
            ]))),
  );

  void _showHobbyDialog(AppLocalizations t) {
    showDialog<void>(context: context,
      builder: (_) => StatefulBuilder(builder: (dialogContext, setDialogState) => _dialog(
        t.translate('choose_hobbies'),
        ListView.separated(itemCount: SurveyData.hobbies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, index) {
              final hobby = SurveyData.hobbies[index];
              final selected = selectedHobbies.contains(hobby);
              return CheckboxListTile(value: selected, title: Text(hobby),
                  activeColor: AuthStyle.accent(context), controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onChanged: !selected && selectedHobbies.length >= 5 ? null : (checked) {
                    setDialogState(() {
                      if (checked == true) { selectedHobbies.add(hobby); }
                      else { selectedHobbies.remove(hobby); }
                    });
                    setState(() {});
                  });
            }),
        footer: AuthButton(text: t.translate('confirm'), onPressed: () => Navigator.pop(dialogContext)),
      )),
    );
  }

  Widget _genderPicker(AppLocalizations t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.translate('gender'), style: TextStyle(fontSize: 13, color: AuthStyle.muted(context))),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 8, children: [
        for (final value in [true, false])
          ChoiceChip(label: Text(t.translate(value ? 'male' : 'female')),
              selected: gender == value, selectedColor: AuthStyle.accent(context).withOpacity(.16),
              backgroundColor: AuthStyle.background(context),
              side: BorderSide(color: gender == value ? AuthStyle.accent(context) : AuthStyle.teal.withOpacity(.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (_) => setState(() => gender = value)),
      ]),
    ]),
  );

  Widget _datePicker(AppLocalizations t) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(controller: birthdayCtrl, readOnly: true,
        decoration: AuthStyle.input(context, t.translate('birthday'), icon: Icons.calendar_month_outlined)
            .copyWith(labelText: t.translate('birthday')),
        validator: (v) => (v == null || v.isEmpty) ? t.translate('choose_birthday') : null,
        onTap: () async {
          DateTime initialDate = DateTime(2000);
          try { initialDate = DateFormat('dd/MM/yyyy').parseStrict(birthdayCtrl.text); } catch (_) {}
          final now = DateTime.now();
          if (initialDate.isBefore(DateTime(1950)) || initialDate.isAfter(now)) initialDate = DateTime(2000);
          final date = await showDatePicker(context: context, builder: (_, child) => AuthSurface(child: child!), firstDate: DateTime(1950),
              lastDate: now, initialDate: initialDate);
          if (mounted && date != null) birthdayCtrl.text = DateFormat('dd/MM/yyyy').format(date);
        }),
  );

  Widget buildDropdown(AppLocalizations t, String label, String value,
      List<String> options, Function(String) onChanged, {bool translateValues = false}) {
    final safeValue = options.contains(value) ? value : (options.isEmpty ? '' : options.first);
    return _selection(label, translateValues ? t.translate(safeValue) : safeValue, () {
      showDialog<void>(context: context,
        builder: (dialogContext) => _dialog('${t.translate('choose')} $label',
            ListView.separated(itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, index) {
                  final item = options[index];
                  final selected = item == safeValue;
                  return Material(color: selected ? AuthStyle.accent(context).withOpacity(.1) : AuthStyle.card(context),
                      borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
                      child: ListTile(selected: selected,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          title: Text(translateValues ? t.translate(item) : item),
                          trailing: selected ? Icon(Icons.check_circle_outline_rounded, color: AuthStyle.accent(context)) : null,
                          onTap: () { onChanged(item); Navigator.pop(dialogContext); }));
                })),
      );
    });
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
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
