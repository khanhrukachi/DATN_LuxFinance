import 'package:personal_financial_management/core/constants/function/finance_toolbar_button.dart';
import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:personal_financial_management/models/user.dart' as myuser;
import 'package:personal_financial_management/setting/localization/app_localizations.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ProfileSurface(
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leadingWidth: 82,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            AppLocalizations.of(context).translate('account'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          leading: FinanceToolbarButton(
            onPressed: () => Navigator.pop(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icons.arrow_back_rounded,
          ),
          centerTitle: true,
          actions: [
            FinanceToolbarButton(
              tooltip: Localizations.localeOf(context).languageCode == 'en'
                  ? 'Edit profile'
                  : 'Chỉnh sửa hồ sơ',
              icon: Icons.edit_outlined,
              onPressed: () => Navigator.pushNamed(context, '/edit_profile'),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection("info")
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final user = myuser.User.fromFirebase(snapshot.requireData);

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundImage: CachedNetworkImageProvider(user.avatar),
                      backgroundColor: ProfileStyle.accent(
                        context,
                      ).withOpacity(.12),
                    ),
                    const SizedBox(height: 24),
                    _buildCardItem(
                      icon: Icons.person,
                      iconColor: Colors.blue,
                      title: AppLocalizations.of(
                        context,
                      ).translate('full_name'),
                      content: user.name,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 12),
                    _buildCardItem(
                      icon: Icons.calendar_today,
                      iconColor: Colors.orange,
                      title: AppLocalizations.of(context).translate('birthday'),
                      content: user.birthday,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 12),
                    _buildCardItem(
                      icon: Icons.male,
                      iconColor: Colors.green,
                      title: AppLocalizations.of(context).translate('gender'),
                      content: user.gender
                          ? AppLocalizations.of(context).translate('male')
                          : AppLocalizations.of(context).translate('female'),
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 12),
                    _buildCardItem(
                      icon: Icons.work,
                      iconColor: Colors.purple,
                      title: AppLocalizations.of(context).translate('job'),
                      content: user.job,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 12),
                    _buildCardItem(
                      icon: Icons.school,
                      iconColor: Colors.teal,
                      title: AppLocalizations.of(
                        context,
                      ).translate('education'),
                      content: user.educationLevel,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 12),
                    _buildCardItem(
                      icon: Icons.location_on,
                      iconColor: Colors.red,
                      title: AppLocalizations.of(
                        context,
                      ).translate('current_address'),
                      content: user.currentAddress,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return ProfileEmpty(
              icon: Icons.cloud_off_outlined,
              text: AppLocalizations.of(
                context,
              ).translate('profile_load_error'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required bool isDarkMode,
  }) {
    return ProfileRow(title: title, value: content, icon: icon);
  }
}
