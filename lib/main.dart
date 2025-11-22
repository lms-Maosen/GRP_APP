import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'ui/screen/home_screen.dart';
import 'ui/theme/app_theme.dart';
import 'i18n/app_localizations.dart';
import 'providers/LocaleProvider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => LocaleProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'Smart Fitness Pod',
      theme: AppTheme.lightTheme,
      // 仅新增以下多语言配置，其余代码与 branch2 完全一致
      locale: localeProvider.currentLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 保留 branch2 原有首页配置
      home: const HomeScreen(username: "当前用户名"),
    );
  }
}