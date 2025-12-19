import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:personal_financial_management/controls/spending_firebase.dart';
import 'package:personal_financial_management/core/constants/app_colors.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
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
        elevation: 2,
        title: Text(AppLocalizations.of(context).translate('account')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
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
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    showAvatar(
                      image: image,
                      url: user.avatar,
                      getImage: (file) => setState(() => image = file),
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          textProfile(AppLocalizations.of(context)
                              .translate('full_name')),
                          TextField(
                            controller: nameController,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 30),

                          textProfile(AppLocalizations.of(context)
                              .translate('birthday')),
                          const SizedBox(height: 20),
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

                          const SizedBox(height: 30),

                          textProfile(AppLocalizations.of(context)
                              .translate('gender')),
                          const SizedBox(height: 30),
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

                          const SizedBox(height: 40),

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
                                    birthday: DateFormat("dd/MM/yyyy")
                                        .format(selectedDate),
                                  ),
                                  image: image,
                                );

                                if (!mounted) return;
                                Navigator.pop(context);
                                Fluttertoast.showToast(
                                  msg: AppLocalizations.of(context)
                                      .translate("success"),
                                );
                                Navigator.pop(context);
                              },
                              child: Text(
                                AppLocalizations.of(context).translate('save'),
                                style: AppStyles.p,
                              ),
                            ),
                          ),
                        ],
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

  // ================= UI =================

  Widget textProfile(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[600],
      ),
    );
  }

  Widget showAvatar({
    File? image,
    required String url,
    required Function(File) getImage,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(90),
      onTap: () => _showBottomSheet(
            (file) => file != null ? getImage(file) : null,
      ),
      child: Stack(
        children: [
          ClipOval(
            child: image == null
                ? CachedNetworkImage(
              imageUrl: url,
              width: 170,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  loadingInfo(width: 150, height: 150, radius: 90),
              errorWidget: (_, __, ___) =>
              const Icon(Icons.error),
            )
                : Image.file(image, width: 170),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(90),
              ),
              child: const Icon(
                FontAwesomeIcons.circlePlus,
                color: Colors.blue,
                size: 28,
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showBottomSheet(Function(File?) getFile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (_) => SizedBox(
        height: 170,
        child: Column(
          children: [
            const Spacer(),
            _pickItem(FontAwesomeIcons.image,
                'select_photo_gallery', () async {
                  Navigator.pop(context);
                  getFile(await chooseAvatar(true));
                }),
            const Spacer(),
            _pickItem(FontAwesomeIcons.camera,
                'take_picture_camera', () async {
                  Navigator.pop(context);
                  getFile(await chooseAvatar(false));
                }),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _pickItem(
      IconData icon, String textKey, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).translate(textKey),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  Widget loadingInfo(
      {required double width, required double height, double radius = 5}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
