import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fitness_pod/providers/LocaleProvider.dart';
import 'package:smart_fitness_pod/i18n/app_localizations.dart';

void main() {
  group('LocaleProvider Tests', () {
    late LocaleProvider localeProvider;

    setUp(() {
      localeProvider = LocaleProvider();
    });

    test('Initial locale should be English', () {
      expect(localeProvider.currentLocale.languageCode, 'en');
    });

    test('setLocale should update locale', () {
      final newLocale = const Locale('zh');
      localeProvider.setLocale(newLocale);
      expect(localeProvider.currentLocale.languageCode, 'zh');
    });

    test('setLocale should reject unsupported locale', () {
      final unsupportedLocale = const Locale('de');
      localeProvider.setLocale(unsupportedLocale);
      expect(localeProvider.currentLocale.languageCode, 'en');
    });
  });
}