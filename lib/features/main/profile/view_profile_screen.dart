import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: Text(AppLocalizations.of(context).translate('account')),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 30),
            onPressed: () => Navigator.pushNamed(context, '/edit_profile'),
          ),
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
            DateTime birthday = DateFormat("dd/MM/yyyy").parse(user.birthday);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 75,
                    backgroundImage: CachedNetworkImageProvider(user.avatar),
                    backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 40),

                  // Full Name
                  _buildCardItem(
                    icon: Icons.person,
                    iconColor: Colors.blue,
                    title: AppLocalizations.of(context).translate('full_name'),
                    content: user.name,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 12),

                  // Birthday
                  _buildCardItem(
                    icon: Icons.calendar_today,
                    iconColor: Colors.orange,
                    title: AppLocalizations.of(context).translate('birthday'),
                    content: DateFormat("dd/MM/yyyy").format(birthday),
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 12),

                  // Gender
                  _buildCardItem(
                    icon: Icons.male,
                    iconColor: Colors.green,
                    title: AppLocalizations.of(context).translate('gender'),
                    content: user.gender
                        ? AppLocalizations.of(context).translate('male')
                        : AppLocalizations.of(context).translate('female'),
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return const Center(child: Text('Error fetching user data.'));
        },
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.15),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          content,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
