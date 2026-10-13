import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_translation_fallback.dart';

/// Translation access for services without BuildContext.
class ServiceLocalizations {
  static const preferenceKey = 'luxfinance_service_language';
  static String _language = 'vi';
  static bool _explicitLanguage = false;
  static Future<void>? _initialization;
  static Future<void> _settingsQueue = Future<void>.value();
  static final Map<String, Map<String, dynamic>> _json = {};

  static String get language => _language;

  static String get numberLocale => language == 'en' ? 'en_US' : 'vi_VN';

  static Map<String, dynamic> get translations =>
      Map<String, dynamic>.unmodifiable(_json[language] ?? const {});

  static String normalize(String code) =>
      code.toLowerCase().startsWith('en') ? 'en' : 'vi';

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(preferenceKey);
      if (!_explicitLanguage && saved != null) _language = normalize(saved);
    } catch (error) {
      debugPrint('Service language preferences unavailable: $error');
    }
    await _loadJson(language);
  }

  static Future<void> setLanguage(String code) {
    _explicitLanguage = true;
    _language = normalize(code);
    final selected = _language;
    _settingsQueue = _settingsQueue
        .then((_) async {
          await initialize();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(preferenceKey, selected);
          await _loadJson(selected);
        })
        .catchError((Object error) {
          debugPrint('Could not persist service language: $error');
        });
    return _settingsQueue;
  }

  static Future<void> _loadJson(String code) async {
    if (_json.containsKey(code)) return;
    try {
      final filename = code == 'en' ? 'en' : 'vn';
      final decoded = jsonDecode(
        await rootBundle.loadString('assets/lang/$filename.json'),
      );
      _json[code] = Map<String, dynamic>.from(decoded as Map);
    } catch (error) {
      // Built-in translations keep validation errors readable during startup.
      debugPrint('Service translation assets unavailable: $error');
    }
  }

  static String text(String key, {Map<String, Object?> args = const {}}) {
    var value =
        _json[language]?[key]?.toString() ??
        serviceFallbackTranslations[language]?[key] ??
        key;
    for (final entry in args.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value?.toString() ?? '');
    }
    return value;
  }

  static String errorText(Object error) {
    if (error is ServiceException) return error.toString();
    if (error is ServiceArgumentException) return error.toString();
    return text('service_unknown_error');
  }
}

/// A stable translation key plus a readable message for existing catch blocks.
class ServiceException extends StateError {
  final String key;
  final Map<String, Object?> args;

  ServiceException(this.key, {this.args = const {}})
    : super(ServiceLocalizations.text(key, args: args));

  @override
  String toString() => ServiceLocalizations.text(key, args: args);
}

class ServiceArgumentException extends ArgumentError {
  final String key;
  final Map<String, Object?> args;

  ServiceArgumentException(this.key, {this.args = const {}})
    : super(ServiceLocalizations.text(key, args: args));

  @override
  String toString() => ServiceLocalizations.text(key, args: args);
}
