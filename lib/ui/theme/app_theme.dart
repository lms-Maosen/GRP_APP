import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.purple,
      scaffoldBackgroundColor: const Color(0xFFC168EE),
      cardColor: const Color(0xFFDDA0DD),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: Colors.black),
      ),
    );
  }
}