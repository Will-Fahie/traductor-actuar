import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  Locale _currentLocale = const Locale('es', ''); // Default to Spanish

  Locale get currentLocale => _currentLocale;
  bool get isSpanish => _currentLocale.languageCode == 'es';
  bool get isEnglish => _currentLocale.languageCode == 'en';

  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'es';
    _currentLocale = Locale(languageCode, '');
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != _currentLocale.languageCode) {
      _currentLocale = Locale(languageCode, '');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      
      notifyListeners();
    }
  }

  Future<void> toggleLanguage() async {
    final newLanguage = _currentLocale.languageCode == 'es' ? 'en' : 'es';
    await setLanguage(newLanguage);
  }

  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'es':
        return 'Español';
      case 'en':
        return 'English';
      default:
        return 'Español';
    }
  }
}
