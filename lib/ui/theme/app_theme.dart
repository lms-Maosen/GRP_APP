import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.purple, // 主色调
      scaffoldBackgroundColor: const Color(0xFFC168EE), // 页面背景深棕色
      cardColor: const Color(0xFFDDA0DD), // 卡片/按钮的淡紫色
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: Colors.black),
      ),
    );
  }
}