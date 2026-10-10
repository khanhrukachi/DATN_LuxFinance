import 'package:personal_financial_management/features/main/profile/widget/profile_style.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:personal_financial_management/setting/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Widget _buildContactButton({
    required BuildContext context,
    required Color color,
    required FaIconData icon,
    required String label,
    required String url,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ProfileStyle.teal.withOpacity(.16)),
      ),
      elevation: 0,
      color: ProfileStyle.card(context), surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (await canLaunchUrlString(url)) {
            await launchUrlString(
              url,
              mode: LaunchMode.externalApplication,
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: ProfileStyle.accent(context).withOpacity(.12),
                child: FaIcon(
                  icon,
                  color: ProfileStyle.accent(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "${AppLocalizations.of(context).translate('contact_me_via')} $label",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return ProfileSurface(child: Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
        ),
        title: Text(
          AppLocalizations.of(context).translate('about'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        child: Column(
          children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: ProfileStyle.decoration(context),
                child: Column(children: [
                  Container(width: 64, height: 64, padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(gradient: ProfileStyle.gradient, borderRadius: BorderRadius.circular(20)),
                      child: Image.asset('assets/logo/logo.png')),
                  const SizedBox(height: 16),
                  Text('LuxFinance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                      color: ProfileStyle.text(context))),
                  const SizedBox(height: 8),
                  Text('${AppLocalizations.of(context).translate('version')} 1.0.0',
                      style: TextStyle(fontSize: 12, color: ProfileStyle.muted(context))),
                  const SizedBox(height: 6),
                  Text('${AppLocalizations.of(context).translate('developed_by')} Rukachi Team',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ProfileStyle.muted(context))),
                ])),
            const SizedBox(height: 20),

            // Facebook
            _buildContactButton(
              context: context,
              color: const Color(0xFF4267B2),
              icon: FontAwesomeIcons.facebookF,
              label: "Facebook",
              url: 'https://fb.com/phamquockhanh7352',
            ),

            // Twitter
            _buildContactButton(
              context: context,
              color: const Color(0xFF1DA1F2),
              icon: FontAwesomeIcons.twitter,
              label: "Twitter",
              url: 'https://twitter.com/rukachilocker',
            ),

            // Telegram
            _buildContactButton(
              context: context,
              color: const Color(0xFF0088CC),
              icon: FontAwesomeIcons.telegram,
              label: "Telegram",
              url: 'https://t.me/rukachiofficial',
            ),

            // Email
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
    ));
  }
}