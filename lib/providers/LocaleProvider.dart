import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  void setLocale(Locale newLocale) {
    if (!AppLocalizations.supportedLocales.contains(newLocale)) return;
    _currentLocale = newLocale;
    notifyListeners();
  }
}