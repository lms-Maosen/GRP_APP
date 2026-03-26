import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fitness_pod/ui/screen/entrance_screen.dart';
import 'package:smart_fitness_pod/ui/screen/home_screen.dart';

void main() {
  testWidgets('EntranceScreen displays logo and welcome text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EntranceScreen()));
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('WELCOME TO'), findsOneWidget);
  });

  testWidgets('EntranceScreen navigates to HomeScreen after 3 seconds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EntranceScreen()));
    // Advance time by 3 seconds
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}