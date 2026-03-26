import 'package:flutter/material.dart';
import 'package:smart_fitness_pod/i18n/app_localizations.dart';

class TestAppLocalizations extends AppLocalizations {
  TestAppLocalizations(Locale locale) : super(locale);

  @override
  String translate(String key) {
    return key; // Return the key as the translation for testing
  }
}

class TestAppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const TestAppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return TestAppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}