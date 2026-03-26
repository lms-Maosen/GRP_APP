import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_fitness_pod/ui/screen/history_tab.dart';
import 'package:smart_fitness_pod/providers/history_provider.dart';
import 'package:smart_fitness_pod/i18n/app_localizations.dart';
import '../helpers/test_app_localizations.dart';

void main() {
  group('HistoryTab Widget Tests', () {
    late HistoryProvider mockProvider;

    setUp(() {
      mockProvider = HistoryProvider();
    });

    testWidgets('Displays record and statistic cards', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mockProvider),
          ],
          child: MaterialApp(
            home: const HistoryTab(),
            localizationsDelegates: const [
              TestAppLocalizationsDelegate(),
            ],
            supportedLocales: const [Locale('en')],
          ),
        ),
      );

      expect(find.text('record'), findsOneWidget);
      expect(find.text('statistic'), findsOneWidget);
    });

    testWidgets('Empty history shows no records message', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mockProvider),
          ],
          child: MaterialApp(
            home: const RecordPage(),
            localizationsDelegates: const [
              TestAppLocalizationsDelegate(),
            ],
            supportedLocales: const [Locale('en')],
          ),
        ),
      );

      expect(find.text('noRecords'), findsOneWidget);
    });

    testWidgets('Record page displays workout entries', (tester) async {
      mockProvider.addSession(WorkoutSession(
        date: DateTime.now(),
        exercises: [ExerciseSet(exerciseName: 'squat', reps: 10, sets: 3)],
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mockProvider),
          ],
          child: MaterialApp(
            home: const RecordPage(),
            localizationsDelegates: const [
              TestAppLocalizationsDelegate(),
            ],
            supportedLocales: const [Locale('en')],
          ),
        ),
      );

      await tester.pump();
      expect(find.text('squat'), findsOneWidget);
    });
  });
}