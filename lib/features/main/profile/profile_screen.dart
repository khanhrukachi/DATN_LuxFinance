import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:personal_financial_management/core/constants/app_colors.dart';
import 'package:personal_financial_management/core/constants/app_styles.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/features/auth/change_password/change_password.dart';
import 'package:personal_financial_management/features/main/profile/export_csv.dart';
import 'package:personal_financial_management/features/main/profile/language_selector.dart';
import 'package:personal_financial_management/features/main/profile/view_profile_screen.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/user.dart' as myuser;
import 'package:intl/intl.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_financial_management/features/main/profile/history_screen.dart';
import 'package:personal_financial_management/features/main/profile/currency_exchange_rate.dart';
import 'package:personal_financial_management/features/main/profile/about_screen.dart';
import 'package:personal_financial_management/features/main/profile/ai_insights_screen.dart';
import 'package:personal_financial_management/setting/bloc/setting_cubit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int language = 0;
  bool darkMode = false;
  bool loginMethod = false;
  final numberFormat = NumberFormat.currency(locale: "vi_VI", symbol: "₫");

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) {
      setState(() {
        language = value.getInt('language') ?? (Platform.localeName.split('_')[0] == "vi" ? 0 : 1);
        darkMode = value.getBool("isDark") ?? false;
        loginMethod = value.getBool("login") ?? false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = darkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("info")
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  myuser.User user = myuser.User.fromFirebase(snapshot.requireData);
                  return _buildAvatarCard(user, isDarkMode);
                }
                return _buildAvatarCard(null, isDarkMode);
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    _buildCard(
                      text: AppLocalizations.of(context).translate('account'),
                      icon: FontAwesomeIcons.solidUser,
                      color: Colors.blue,
                      isDarkMode: isDarkMode,
                      action: () => Navigator.of(context).push(createRoute(
                        screen: const UserProfilePage(),
                        begin: const Offset(1, 0),
                      )),
                    ),
                    if (loginMethod) ...[
                      const SizedBox(height: 12),
                      _buildCard(
                        text: AppLocalizations.of(context).translate('change_password'),
                        icon: FontAwesomeIcons.lock,
                        color: Colors.deepOrange,
                        isDarkMode: isDarkMode,
                        action: () => Navigator.of(context).push(createRoute(
                          screen: const ChangePassword(),
                          begin: const Offset(1, 0),
                        )),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildCard(
                      text: AppLocalizations.of(context).translate('language'),
                      icon: Icons.translate_outlined,
                      color: Colors.amber,
                      isDarkMode: isDarkMode,
                      action: _showBottomSheet,
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchCard(
                      text: AppLocalizations.of(context).translate('dark_mode'),
                      icon: FontAwesomeIcons.solidMoon,
                      value: darkMode,
                      isDarkMode: isDarkMode,
                      onToggle: (val) async {
                        BlocProvider.of<SettingCubit>(context).changeTheme();
                        setState(() => darkMode = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('isDark', darkMode);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      text: AppLocalizations.of(context).translate('history'),
                      icon: Icons.history_rounded,
                      color: Colors.green,
                      isDarkMode: isDarkMode,
                      action: () => Navigator.of(context).push(createRoute(
                        screen: const HistoryPage(),
                        begin: const Offset(1, 0),
                      )),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      text: AppLocalizations.of(context).translate('ai_insights'),
                      icon: Icons.auto_awesome,
                      color: Colors.purple,
                      isDarkMode: isDarkMode,
                      action: () => Navigator.of(context).push(createRoute(
                        screen: const AIInsightsScreen(),
                        begin: const Offset(1, 0),
                      )),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      text: "${AppLocalizations.of(context).translate('export')} CSV",
                      icon: Icons.archive_outlined,
                      color: Colors.lightBlue,
                      isDarkMode: isDarkMode,
                      action: () async {
                        loadingAnimation(context);
                        await ExportCSV.exportCSV(context);
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      text: AppLocalizations.of(context).translate('about'),
                      icon: FontAwesomeIcons.circleInfo,
                      color: Colors.teal,
                      isDarkMode: isDarkMode,
                      action: () => Navigator.of(context).push(createRoute(
                        screen: const AboutPage(),
                        begin: const Offset(1, 0),
                      )),
                    ),
                    const SizedBox(height: 24),
                    _buildLogoutButton(isDarkMode),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCard(myuser.User? user, bool isDarkMode) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: user != null ? NetworkImage(user.avatar) : null,
            backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? "User",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user?.money != null ? numberFormat.format(user!.money) : "0 ₫",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.amberAccent : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback action,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: action,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchCard({
    required String text,
    required IconData icon,
    required bool value,
    required Function(bool) onToggle,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.black12,
            child: Icon(icon, color: Colors.black87, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          FlutterSwitch(
            height: 30,
            width: 60,
            value: value,
            onToggle: onToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(bool isDarkMode) {
    return GestureDetector(
      onTap: () async {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        await FacebookAuth.instance.logOut();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.buttonLogin,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context).translate('logout'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      context: context,
      builder: (context) {
        return LanguageSelector(
          currentLanguage: language,
          onLanguageChanged: (lang) async {
            changeLanguage(lang);
          },
        );
      },
    );
  }

  Future changeLanguage(int lang) async {
    if (lang != language) {
      if (lang == 0) {
        BlocProvider.of<SettingCubit>(context).toVietnamese();
      } else {
        BlocProvider.of<SettingCubit>(context).toEnglish();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('language', lang);
      if (!mounted) return;
      setState(() => language = lang);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }
}
