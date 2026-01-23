import 'package:flutter/material.dart';

class _BeautifulTab extends StatelessWidget {
  final IconData icon;
  final String textVi;
  final String textEn;

  const _BeautifulTab({
    required this.icon,
    required this.textVi,
    required this.textEn,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    return Tab(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            lang == 'vi' ? textVi : textEn,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
