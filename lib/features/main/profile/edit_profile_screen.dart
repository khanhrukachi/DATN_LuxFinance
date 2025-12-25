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
                    // Thông tin cá nhân
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
                    const SizedBox(height: 30),
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
                              birthday:
                              DateFormat("dd/MM/yyyy").format(selectedDate),
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
              placeholder: (_, __) =>
                  Shimmer.fromColors(
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
