import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/pick_function.dart';
import 'package:personal_financial_management/features/main/profile/widget/show_birthday.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/user.dart' as myuser;
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/function/get_survey_data.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  @override
  Widget build(BuildContext context) {
    return ProfileSurface(child: Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('account')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder(
        future: FirebaseFirestore.instance
            .collection("info")
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = myuser.User.fromFirebase(snapshot.requireData);
          final nameController = TextEditingController(text: user.name);
          bool gender = user.gender;
          File? image;
          DateTime selectedDate =
          DateFormat("dd/MM/yyyy").parse(user.birthday);

          return StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    showAvatar(
                      image: image,
                      url: user.avatar,
                      getImage: (file) => setState(() => image = file),
                    ),
                    const SizedBox(height: 30),

                    // Tên đầy đủ
                    _infoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(AppLocalizations.of(context).translate('full_name')),
                          TextField(
                            controller: nameController,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: ProfileStyle.input(context, AppLocalizations.of(context).translate('full_name'), icon: Icons.person_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ngày sinh
                    _infoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(AppLocalizations.of(context).translate('birthday')),
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                builder: (_, child) => ProfileSurface(child: child!),
                                initialDate: selectedDate,
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                              }
                            },
                            child: showBirthday(selectedDate),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Giới tính
                    _infoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(AppLocalizations.of(context).translate('gender')),
                          const SizedBox(height: 10),
                          Wrap(spacing: 10, runSpacing: 8, children: [
                            for (final value in [true, false])
                              ChoiceChip(label: Text(AppLocalizations.of(context).translate(value ? 'male' : 'female')),
                                  selected: gender == value,
                                  selectedColor: ProfileStyle.accent(context).withOpacity(.14),
                                  backgroundColor: ProfileStyle.background(context),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: BorderSide(color: gender == value ? ProfileStyle.accent(context) : ProfileStyle.teal.withOpacity(.2)),
                                  onSelected: (_) => setState(() => gender = value)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Thông tin xã hội & nghề nghiệp
                    _infoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDropdown(
                            label: AppLocalizations.of(context).translate('current_address'),
                            value: SurveyData.provinces.contains(user.currentAddress)
                                ? user.currentAddress
                                : SurveyData.provinces.first,
                            options: SurveyData.provinces,
                            onChanged: (v) => setState(() => user.currentAddress = v),
                          ),
                          _buildDropdown(
                            label: AppLocalizations.of(context).translate('marital_status'),
                            value: ["Độc thân", "Đã kết hôn", "Khác"].contains(user.maritalStatus)
                                ? user.maritalStatus
                                : "Độc thân",
                            options: ["Độc thân", "Đã kết hôn", "Khác"],
                            onChanged: (v) => setState(() => user.maritalStatus = v),
                          ),
                          _buildDropdown(
                            label: AppLocalizations.of(context).translate('job'),
                            value: SurveyData.jobs.contains(user.job) ? user.job : SurveyData.jobs.first,
                            options: SurveyData.jobs,
                            onChanged: (v) => setState(() => user.job = v),
                          ),
                          _buildDropdown(
                            label: AppLocalizations.of(context).translate('education'),
                            value: SurveyData.educationLevels.contains(user.educationLevel)
                                ? user.educationLevel
                                : SurveyData.educationLevels.first,
                            options: SurveyData.educationLevels,
                            onChanged: (v) => setState(() => user.educationLevel = v),
                          ),
                          _buildDropdown(
                            label: AppLocalizations.of(context).translate('lifestyle'),
                            value: ["Tiết kiệm", "Cân bằng", "Hưởng thụ"].contains(user.lifestyle)
                                ? user.lifestyle
                                : "Cân bằng",
                            options: ["Tiết kiệm", "Cân bằng", "Hưởng thụ"],
                            onChanged: (v) => setState(() => user.lifestyle = v),
                          ),
                          _buildDropdown(
                            label: AppLocalizations.of(context).translate('risk_tolerance'),
                            value: ["Thấp", "Trung bình", "Cao"].contains(user.riskTolerance)
                                ? user.riskTolerance
                                : "Trung bình",
                            options: ["Thấp", "Trung bình", "Cao"],
                            onChanged: (v) => setState(() => user.riskTolerance = v),
                          ),
                          _buildMultiSelectDropdown(
                            label: AppLocalizations.of(context).translate('hobbies'),
                            values: user.hobbies,
                            options: SurveyData.hobbies,
                            onChanged: (list) => setState(() => user.hobbies = list),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Nút lưu
                    ProfileButton(text: AppLocalizations.of(context).translate('save'),
                        onPressed:  () async {
                          loadingAnimation(context);
                          await SpendingFirebase.updateInfo(
                            user: user.copyWith(
                              name: nameController.text.trim(),
                              gender: gender,
                              birthday: DateFormat("dd/MM/yyyy").format(selectedDate),
                            ),
                            image: image,
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                          Fluttertoast.showToast(
                            msg: AppLocalizations.of(context).translate("success"),
                          );
                          Navigator.pop(context);
                        }),
                  ],
                ),
              );
            },
          );
        },
      ),
    ));
  }

  String _optionLabel(String value) {
    const keys = <String, String>{
      'Độc thân': 'single', 'Đã kết hôn': 'married', 'Khác': 'other',
      'Tiết kiệm': 'saving', 'Cân bằng': 'balanced', 'Hưởng thụ': 'enjoy',
      'Thấp': 'low', 'Trung bình': 'medium', 'Cao': 'high',
    };
    return keys.containsKey(value) ? AppLocalizations.of(context).translate(keys[value]!) : value;
  }

  Widget _buildDropdown({required String label, required String value,
    required List<String> options, required Function(String) onChanged}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _label(label), const SizedBox(height: 8),
    ProfileSelection(value: _optionLabel(value), onTap: () {
      showDialog<void>(context: context, builder: (dialogContext) => ProfilePickerDialog(
          title: '${AppLocalizations.of(context).translate('choose')} $label',
          child: ListView.separated(itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, index) {
                final item = options[index]; final selected = item == value;
                return Material(color: selected ? ProfileStyle.accent(context).withOpacity(.1) : ProfileStyle.card(context),
                    borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
                    child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text(_optionLabel(item)),
                        trailing: selected ? Icon(Icons.check_circle_outline_rounded, color: ProfileStyle.accent(context)) : null,
                        onTap: () { onChanged(item); Navigator.pop(dialogContext); }));
              })));
    }), const SizedBox(height: 14),
  ]);

  Widget _buildMultiSelectDropdown({required String label, required List<String> values,
    required List<String> options, required Function(List<String>) onChanged}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _label(label), const SizedBox(height: 8),
    ProfileSelection(value: values.isEmpty ? AppLocalizations.of(context).translate('choose_hobbies') : values.join(', '),
        onTap: () {
          final selected = List<String>.from(values);
          showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
              builder: (_, updateDialog) => ProfilePickerDialog(
                title: '${AppLocalizations.of(context).translate('choose')} $label',
                child: ListView.builder(itemCount: options.length, itemBuilder: (_, index) {
                  final item = options[index];
                  return CheckboxListTile(value: selected.contains(item), title: Text(item),
                      activeColor: ProfileStyle.accent(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onChanged: (checked) => updateDialog(() {
                        if (checked == true) { selected.add(item); } else { selected.remove(item); }
                      }));
                }),
                footer: ProfileButton(text: AppLocalizations.of(context).translate('confirm'),
                    onPressed: () { onChanged(selected); Navigator.pop(dialogContext); }),
              )));
        }), const SizedBox(height: 14),
  ]);

  Widget _infoCard({required Widget child}) => Material(
      color: ProfileStyle.card(context), clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ProfileStyle.teal.withOpacity(.16))),
      child: Padding(padding: const EdgeInsets.all(18), child: child));

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: ProfileStyle.muted(context))));

  Widget showAvatar({
    File? image,
    required String url,
    required Function(File) getImage,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(90),
      onTap: () => _showBottomSheet((file) => file != null ? getImage(file) : null),
      child: Stack(
        children: [
          ClipOval(
            child: image == null
                ? CachedNetworkImage(
              imageUrl: url,
              width: 104,
              height: 104,
              fit: BoxFit.cover,
              placeholder: (_, __) => Shimmer.fromColors(
                baseColor: ProfileStyle.background(context),
                highlightColor: ProfileStyle.teal.withOpacity(.15),
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(70),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => const Icon(Icons.error),
            )
                : Image.file(image, width: 104, height: 104, fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: ProfileStyle.card(context),
              child: FaIcon(
                FontAwesomeIcons.circlePlus,
                color: ProfileStyle.accent(context),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBottomSheet(Function(File?) getFile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ProfileStyle.card(context),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: 160,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _pickItem(FontAwesomeIcons.image, 'select_photo_gallery', () async {
              Navigator.pop(context);
              getFile(await chooseAvatar(true));
            }),
            const SizedBox(height: 10),
            _pickItem(FontAwesomeIcons.camera, 'take_picture_camera', () async {
              Navigator.pop(context);
              getFile(await chooseAvatar(false));
            }),
          ],
        ),
      ),
    );
  }

  Widget _pickItem(
      FaIconData icon,
      String textKey,
      VoidCallback onTap,
      ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 10,
        ),
        child: Row(
          children: [
            FaIcon(
              icon,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
              AppLocalizations.of(context).translate(textKey),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<File?> chooseAvatar(bool fromGallery) async {
    try {
      final picked = await pickImage(fromGallery);
      if (picked == null) return null;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
      );

      return cropped != null ? File(cropped.path) : null;
    } catch (_) {
      return null;
    }
  }
}
