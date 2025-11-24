import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'settings_tab.dart';
// 新增：导入多语言工具类
import '../../i18n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const HistoryTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // 新增：获取多语言实例
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: Container(
                child: const Text('Welcome')
            )
        ),
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: const Color(0xFFC168EE),
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // 关键修改：移除 const，替换 label 为多语言翻译
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: loc.translate('home'), // 替换固定英文为翻译
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: loc.translate('history'), // 替换固定英文为翻译
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: loc.translate('settings'), // 替换固定英文为翻译
          ),
        ],
      ),
    );
  }
}