import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_fitness_pod/providers/history_provider.dart';
import 'package:smart_fitness_pod/ui/screen/home_tab.dart';
import 'package:smart_fitness_pod/i18n/app_localizations.dart';

void main() {
  // Bluetooth-dependent tests are performed using integration tests on real devices.
  testWidgets('HomeTab UI (skipped)', (tester) async {
    // This test is intentionally skipped.
  }, skip: true);
}