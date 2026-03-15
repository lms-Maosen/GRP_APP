import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'settings_tab.dart';
import '../../i18n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _bottomNavEnabled = true; // 控制底部导航栏是否可用

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Welcome')),
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: const Color(0xFFC168EE),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        // 根据 _bottomNavEnabled 决定是否响应点击
        onTap: _bottomNavEnabled
            ? (index) {
          setState(() {
            _currentIndex = index;
          });
        }
            : null, // 禁用时 onTap 为 null，则无法点击
        // 动态设置颜色以反映禁用状态
        selectedItemColor: _bottomNavEnabled ? null : Colors.grey,
        unselectedItemColor: _bottomNavEnabled ? null : Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: loc.translate('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: loc.translate('history'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: loc.translate('settings'),
          ),
        ],
      ),
    );
  }

  // 根据当前选中的标签页返回对应的 Widget
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return HomeTab(
          onConnectionStateChanged: (enabled) {
            setState(() {
              _bottomNavEnabled = enabled;
            });
          },
        );
      case 1:
        return const HistoryTab();
      case 2:
        return const SettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }
}