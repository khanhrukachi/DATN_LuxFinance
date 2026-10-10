import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:personal_financial_management/core/constants/function/loading_animation.dart';
import 'package:personal_financial_management/core/constants/function/route_function.dart';
import 'package:personal_financial_management/features/auth/change_password/change_password.dart';
import 'package:personal_financial_management/features/main/profile/export_csv.dart';
import 'package:personal_financial_management/features/main/profile/language_selector.dart';
import 'package:personal_financial_management/features/main/profile/view_profile_screen.dart';
import 'package:personal_financial_management/controls/notification_service.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:personal_financial_management/models/user.dart' as myuser;
import 'package:intl/intl.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_financial_management/features/main/profile/history_screen.dart';
import 'package:personal_financial_management/features/main/profile/about_screen.dart';
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

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) {
      if (!mounted) return;
      setState(() {
        language = value.getInt('language') ?? (Platform.localeName.split('_')[0] == "vi" ? 0 : 1);
        darkMode = value.getBool("isDark") ?? false;
        loginMethod = value.getBool("login") ?? false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _background(isDarkMode),
      body: SafeArea(
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseAuth.instance.currentUser == null
                  ? null
                  : FirebaseFirestore.instance
                  .collection("info")
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
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
                      icon: FontAwesomeIcons.language,

                      isDarkMode: isDarkMode,
                      action: _showBottomSheet,
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchCard(
                      text: AppLocalizations.of(context).translate('dark_mode'),
                      icon: FontAwesomeIcons.solidMoon,
                      value: isDarkMode,
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
                      icon: FontAwesomeIcons.clockRotateLeft,

                      isDarkMode: isDarkMode,
                      action: () => Navigator.of(context).push(createRoute(
                        screen: const HistoryPage(),
                        begin: const Offset(1, 0),
                      )),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      text: "${AppLocalizations.of(context).translate('export')} CSV",
                      icon: FontAwesomeIcons.fileExport,

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

  static const _cyan = Color(0xFF00D2FF);
  static const _teal = Color(0xFF2DD8C6);
  static const _gradient = LinearGradient(
    colors: [_cyan, _teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Color _background(bool dark) =>
      dark ? const Color(0xFF0E1C22) : const Color(0xFFF3F9FA);
  Color _card(bool dark) => dark ? const Color(0xFF172A30) : Colors.white;
  Color _accent(bool dark) => dark ? _teal : const Color(0xFF14988F);

  Widget _buildAvatarCard(myuser.User? user, bool isDarkMode) {
    final colors = Theme.of(context).colorScheme;
    final avatar = user?.avatar.trim() ?? '';
    final formatter = NumberFormat.currency(
      locale: Localizations.localeOf(context).languageCode == 'vi'
          ? 'vi_VN' : 'en_US',
      symbol: '₫',
      decimalDigits: 0,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF163A46), const Color(0xFF16463F)]
              : [const Color(0xFFE1F7FF), const Color(0xFFDCF9F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _teal.withOpacity(.18)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              gradient: _gradient,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: SizedBox(
                width: 90,
                height: 90,
                child: avatar.isEmpty
                    ? _avatarPlaceholder(isDarkMode)
                    : Image.network(
                  avatar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _avatarPlaceholder(isDarkMode),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? FirebaseAuth.instance.currentUser?.displayName ?? '—',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _card(isDarkMode).withOpacity(.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _teal.withOpacity(.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 20, color: _accent(isDarkMode)),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    user?.money == null ? '—' : formatter.format(user!.money),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: _accent(isDarkMode),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder(bool dark) => ColoredBox(
    color: _card(dark),
    child: Icon(Icons.person_outline_rounded, size: 44, color: _accent(dark)),
  );

  Widget _menuIcon(FaIconData icon, bool dark) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _teal.withOpacity(.10),
      borderRadius: BorderRadius.circular(14),
    ),
    child: FaIcon(icon, color: _accent(dark), size: 21),
  );

  Widget _menuSurface({
    required bool dark,
    required Widget child,
    VoidCallback? onTap,
  }) => Material(
    color: _card(dark),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: _teal.withOpacity(.16)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      splashColor: _teal.withOpacity(.14),
      highlightColor: _teal.withOpacity(.06),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  Widget _buildCard({
    required String text,
    required FaIconData icon,
    required VoidCallback action,
    required bool isDarkMode,
  }) => _menuSurface(
    dark: isDarkMode,
    onTap: action,
    child: Row(
      children: [
        _menuIcon(icon, isDarkMode),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: TextStyle(
            fontSize: 14, height: 1.45, fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          )),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, size: 22, color: _accent(isDarkMode)),
      ],
    ),
  );

  Widget _buildSwitchCard({
    required String text,
    required FaIconData icon,
    required bool value,
    required Function(bool) onToggle,
    required bool isDarkMode,
  }) => _menuSurface(
    dark: isDarkMode,
    child: Row(
      children: [
        _menuIcon(icon, isDarkMode),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: TextStyle(
          fontSize: 14, height: 1.45, fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ))),
        const SizedBox(width: 10),
        FlutterSwitch(
          height: 28,
          width: 50,
          toggleSize: 20,
          padding: 4,
          value: value,
          activeColor: _teal,
          activeToggleColor: const Color(0xFF073D43),
          inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(.15),
          inactiveToggleColor: _card(isDarkMode),
          onToggle: onToggle,
        ),
      ],
    ),
  );

  Widget _buildLogoutButton(bool isDarkMode) => Material(
    color: Colors.transparent,

    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () async {
          await NotificationService().clearSession();
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();
          await FacebookAuth.instance.logOut();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFF073D43), size: 21),
              const SizedBox(width: 10),
              Flexible(child: Text(
                AppLocalizations.of(context).translate('logout'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Color(0xFF073D43)),
              )),
            ],
          ),
        ),
      ),
    ),
  );

  void _showBottomSheet() {
    showModalBottomSheet(
      backgroundColor: _card(Theme.of(context).brightness == Brightness.dark),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
