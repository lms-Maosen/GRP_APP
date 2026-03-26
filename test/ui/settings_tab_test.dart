import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_fitness_pod/providers/LocaleProvider.dart';
import 'package:smart_fitness_pod/providers/history_provider.dart';
import 'package:smart_fitness_pod/ui/screen/settings_tab.dart';
import 'package:smart_fitness_pod/i18n/app_localizations.dart';
import '../helpers/test_app_localizations.dart';

void main() {
  testWidgets('SettingsTab displays language and clean history items', (tester) async {
    final localeProvider = LocaleProvider();
    final historyProvider = HistoryProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeProvider),
          ChangeNotifierProvider.value(value: historyProvider),
        ],
        child: MaterialApp(
          home: const SettingsTab(),
          localizationsDelegates: const [
            TestAppLocalizationsDelegate(),
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );

    expect(find.text('language'), findsOneWidget);
    expect(find.text('cleanHistory'), findsOneWidget);
  });

  testWidgets('Tapping language opens dialog with language options', (tester) async {
    final localeProvider = LocaleProvider();
    final historyProvider = HistoryProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeProvider),
          ChangeNotifierProvider.value(value: historyProvider),
        ],
        child: MaterialApp(
          home: const SettingsTab(),
          localizationsDelegates: const [
            TestAppLocalizationsDelegate(),
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );

    await tester.tap(find.text('language'));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Simplified Chinese'), findsOneWidget);
    expect(find.text('Traditional Chinese'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
  });

  testWidgets('Tapping clean history shows confirmation dialog', (tester) async {
    final localeProvider = LocaleProvider();
    final historyProvider = HistoryProvider();

    historyProvider.addSession(WorkoutSession(
      date: DateTime.now(),
      exercises: [ExerciseSet(exerciseName: 'squat', reps: 10, sets: 3)],
    ));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: localeProvider),
          ChangeNotifierProvider.value(value: historyProvider),
        ],
        child: MaterialApp(
          home: const SettingsTab(),
          localizationsDelegates: const [
            TestAppLocalizationsDelegate(),
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );

    await tester.tap(find.text('cleanHistory'));
    await tester.pumpAndSettle();

    expect(find.text('confirmCleanHistory'), findsOneWidget);
    expect(find.text('confirm'), findsOneWidget);
    expect(find.text('cancel'), findsOneWidget);
  });
}