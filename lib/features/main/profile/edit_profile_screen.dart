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
import 'package:personal_financial_management/core/constants/app_colors.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/pick_function.dart';
import 'package:personal_financial_management/features/main/profile/widget/show_birthday.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/user.dart' as myuser;
import 'package:shimmer/shimmer.dart';
import 'package:personal_financial_management/features/auth/signup/gender_widget.dart';
import '../../../core/constants/function/get_survey_data.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                fontSize: 18, fontWeight: FontWeight.w600),
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
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
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
                          Row(
                            children: [
                              const Spacer(),
                              GenderWidget(
                                currentGender: gender,
                                gender: true,
                                action: () => setState(() => gender = true),
                              ),
                              const Spacer(),
                              GenderWidget(
                                currentGender: gender,
                                gender: false,
                                action: () => setState(() => gender = false),
                              ),
                              const Spacer(),
                            ],
                          ),
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
                            label: "Nơi ở hiện tại",
                            value: SurveyData.provinces.contains(user.currentAddress)
                                ? user.currentAddress
                                : SurveyData.provinces.first,
                            options: SurveyData.provinces,
                            onChanged: (v) => setState(() => user.currentAddress = v),
                          ),
                          _buildDropdown(
                            label: "Tình trạng hôn nhân",
                            value: ["Độc thân", "Đã kết hôn", "Khác"].contains(user.maritalStatus)
                                ? user.maritalStatus
                                : "Độc thân",
                            options: ["Độc thân", "Đã kết hôn", "Khác"],
                            onChanged: (v) => setState(() => user.maritalStatus = v),
                          ),
                          _buildDropdown(
                            label: "Ngành nghề",
                            value: SurveyData.jobs.contains(user.job) ? user.job : SurveyData.jobs.first,
                            options: SurveyData.jobs,
                            onChanged: (v) => setState(() => user.job = v),
                          ),
                          _buildDropdown(
                            label: "Trình độ học vấn",
                            value: SurveyData.educationLevels.contains(user.educationLevel)
                                ? user.educationLevel
                                : SurveyData.educationLevels.first,
                            options: SurveyData.educationLevels,
                            onChanged: (v) => setState(() => user.educationLevel = v),
                          ),
                          _buildDropdown(
                            label: "Lối sống",
                            value: ["Tiết kiệm", "Cân bằng", "Hưởng thụ"].contains(user.lifestyle)
                                ? user.lifestyle
                                : "Cân bằng",
                            options: ["Tiết kiệm", "Cân bằng", "Hưởng thụ"],
                            onChanged: (v) => setState(() => user.lifestyle = v),
                          ),
                          _buildDropdown(
                            label: "Khẩu vị rủi ro",
                            value: ["Thấp", "Trung bình", "Cao"].contains(user.riskTolerance)
                                ? user.riskTolerance
                                : "Trung bình",
                            options: ["Thấp", "Trung bình", "Cao"],
                            onChanged: (v) => setState(() => user.riskTolerance = v),
                          ),
                          _buildMultiSelectDropdown(
                            label: "Sở thích",
                            values: user.hobbies,
                            options: SurveyData.hobbies,
                            onChanged: (list) => setState(() => user.hobbies = list),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Nút lưu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.buttonLogin,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () async {
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
                        },
                        child: Text(
                          AppLocalizations.of(context).translate('save'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Helper Dropdown
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              barrierColor: Colors.black.withOpacity(0.3),
              builder: (_) => Center(
                child: Material( // ✅ BẮT BUỘC
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.height * 0.5,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface, // 🌗 dark/light
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Chọn $label",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: options.length,
                            itemBuilder: (_, index) {
                              final item = options[index];
                              return ListTile(
                                title: Text(item),
                                trailing: item == value
                                    ? Icon(Icons.check,
                                    color: Theme.of(context).colorScheme.primary)
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
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMultiSelectDropdown({
    required String label,
    required List<String> values,
    required List<String> options,
    required Function(List<String>) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),

        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            final tempSelected = List<String>.from(values);

            showDialog(
              context: context,
              barrierColor: Colors.black.withOpacity(0.4),
              builder: (_) => Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.height * 0.6,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Chọn $label",
                          style: theme.textTheme.titleMedium,
                        ),
                        Divider(color: colorScheme.outline),

                        Expanded(
                          child: StatefulBuilder(
                            builder: (context, setStateDialog) {
                              return ListView.builder(
                                itemCount: options.length,
                                itemBuilder: (_, index) {
                                  final item = options[index];
                                  final isSelected =
                                  tempSelected.contains(item);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    title: Text(item),
                                    activeColor: colorScheme.primary,
                                    onChanged: (checked) {
                                      setStateDialog(() {
                                        if (checked == true) {
                                          tempSelected.add(item);
                                        } else {
                                          tempSelected.remove(item);
                                        }
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 8),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              onChanged(tempSelected);
                              Navigator.pop(context);
                            },
                            child: const Text("Xác nhận"),
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
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surface,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    values.isEmpty
                        ? "Chọn sở thích"
                        : values.join(", "),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _infoCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
    );
  }

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
              width: 140,
              height: 140,
              fit: BoxFit.cover,
              placeholder: (_, __) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(70),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => const Icon(Icons.error),
            )
                : Image.file(image, width: 140, height: 140, fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: const Icon(
                FontAwesomeIcons.circlePlus,
                color: Colors.blue,
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

  Widget _pickItem(IconData icon, String textKey, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context).translate(textKey),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
