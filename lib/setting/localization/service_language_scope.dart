import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:personal_financial_management/controls/debt_reminder_service.dart';
import 'package:personal_financial_management/controls/notification_service.dart';
import 'service_localizations.dart';

/// Put inside MaterialApp.builder so it sees the application's current locale.
class ServiceLanguageScope extends StatefulWidget {
  final Widget child;

  const ServiceLanguageScope({super.key, required this.child});

  @override
  State<ServiceLanguageScope> createState() => _ServiceLanguageScopeState();
}

class _ServiceLanguageScopeState extends State<ServiceLanguageScope> {
  String? _code;
  Future<void> _queue = Future<void>.value();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = ServiceLocalizations.normalize(
      Localizations.localeOf(context).languageCode,
    );
    if (_code == code) return;
    _code = code;
    final saved = ServiceLocalizations.setLanguage(code);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _queue = _queue
          .then((_) async {
            await saved;
            if (!mounted || _code != code) return;
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) return;

            final notifications = NotificationService();
            await notifications.initialize();
            if (!mounted ||
                _code != code ||
                FirebaseAuth.instance.currentUser?.uid != uid) {
              return;
            }
            await notifications.refreshLocalizedSchedules();
            if (!mounted ||
                _code != code ||
                FirebaseAuth.instance.currentUser?.uid != uid) {
              return;
            }
            await DebtReminderService.instance.refreshSafely(uid);
          })
          .catchError((Object error) {
            debugPrint('Could not refresh localized reminders: $error');
          });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
