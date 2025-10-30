import 'package:flutter/material.dart';
// 导入自定义入口页（注意路径是 screen 单数，与你的文件夹名匹配）
import 'ui/screen/entrance_screen.dart';
// 导入自定义主题配置
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Fitness Pod', // 应用名称（替换默认的 Flutter Demo）
      theme: AppTheme.lightTheme, // 使用自定义义的主题配置
      // 初始页面设置为入口页（EntranceScreen）
      home: const EntranceScreen(),
    );
  }
}