import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
    // Check if the current theme is dark or light
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: Text(AppLocalizations.of(context).translate('account')),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 30),
            onPressed: () {
              Navigator.pushNamed(context, '/edit_profile');
            },
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
            myuser.User user = myuser.User.fromFirebase(snapshot.requireData);
            DateTime selectedDate =
            DateFormat("dd/MM/yyyy").parse(user.birthday);

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 75,
                      backgroundImage: CachedNetworkImageProvider(user.avatar),
                      backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                    const SizedBox(height: 75),

                    _buildProfileInfo(
                      title: AppLocalizations.of(context).translate('full_name'),
                      content: Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 16),

                    _buildProfileInfo(
                      title: AppLocalizations.of(context).translate('monthly_money'),
                      content: Text(
                        NumberFormat.currency(locale: "vi_VI").format(user.money),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 16),

                    _buildProfileInfo(
                      title: AppLocalizations.of(context).translate('birthday'),
                      content: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat("dd/MM/yyyy").format(selectedDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,  // Make the date bold
                            ),
                          ),
                        ],
                      ),
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 16),

                    _buildProfileInfo(
                      title: AppLocalizations.of(context).translate('gender'),
                      content: Text(
                        user.gender
                            ? AppLocalizations.of(context).translate('male')
                            : AppLocalizations.of(context).translate('female'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
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

  Widget _buildProfileInfo({required String title, required Widget content, required bool isDarkMode}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget showBirthday(DateTime selectedDate) {
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: Colors.grey),
        const SizedBox(width: 10),
        Text(
          DateFormat("dd/MM/yyyy").format(selectedDate),
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
