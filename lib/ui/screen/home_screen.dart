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
  bool _bottomNavEnabled = true; // Control whether the bottom navigation bar is enabled.

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
        // Determine whether to respond to clicks based on _bottomNavEnabled.
        onTap: _bottomNavEnabled
            ? (index) {
          setState(() {
            _currentIndex = index;
          });
        }
            : null, // When disabled, onTap is null, so it cannot be clicked.
        // Dynamically set color to reflect disabled state.
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

  // Return the corresponding Widget based on the currently selected tab.
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