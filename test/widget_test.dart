import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_fitness_pod/main.dart';
import 'package:smart_fitness_pod/providers/LocaleProvider.dart';
import 'package:smart_fitness_pod/providers/history_provider.dart';
import 'helpers/test_app_localizations.dart';

void main() {
  testWidgets('App starts without crashing', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ],
        child: MaterialApp(
          home: const MyApp(),
          localizationsDelegates: const [
            TestAppLocalizationsDelegate(),
          ],
          supportedLocales: const [Locale('en')],
        ),
      ),
    );
    expect(find.byType(MyApp), findsOneWidget);
  });
}