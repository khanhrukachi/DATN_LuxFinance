import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  Widget _buildContactButton({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (await canLaunchUrlString(url)) {
            await launchUrlString(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "${AppLocalizations.of(context).translate('contact_me_via')} $label",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(AppLocalizations.of(context).translate('about'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            Image.asset("assets/logo/logo.png", width: 120),
            const SizedBox(height: 12),
            const Text(
              "LuxFinance",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text("${AppLocalizations.of(context).translate('version')} 1.0.0",
                style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 4),
            Text(
              "${AppLocalizations.of(context).translate('developed_by')} Rukachi Team",
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 24),
            _buildContactButton(
              context: context,
              color: const Color(0xFF4267B2),
              icon: FontAwesomeIcons.facebookF,
              label: "Facebook",
              url: 'https://fb.com/phamquockhanh7352',
            ),
            _buildContactButton(
              context: context,
              color: const Color(0xFF1DA1F2),
              icon: FontAwesomeIcons.twitter,
              label: "Twitter",
              url: 'https://twitter.com/rukachilocker',
            ),
            _buildContactButton(
              context: context,
              color: const Color(0xFF0088CC),
              icon: FontAwesomeIcons.telegram,
              label: "Telegram",
              url: 'https://t.me/rukachiofficial',
            ),
            _buildContactButton(
              context: context,
              color: Colors.red,
              icon: FontAwesomeIcons.envelope,
              label: "Email",
              url:
              'mailto:phamquockhanh.dev@gmail.com?subject=Spending Manager&body=Hello Phạm Quốc Khánh',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
