import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/app_localizations.dart';
import '../../providers/LocaleProvider.dart';
import '../../providers/history_provider.dart';
import 'package:provider/provider.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  final List<Map<String, dynamic>> _languages = const [
    {'name': 'English', 'code': Locale('en')},
    {'name': 'Simplified Chinese', 'code': Locale('zh')},
    {'name': 'Traditional Chinese', 'code': Locale('zh', 'TW')},
    {'name': 'French', 'code': Locale('fr')},
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLangName = _languages.firstWhere(
          (lang) => lang['code'] == localeProvider.currentLocale,
      orElse: () => _languages[0],
    )['name'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC168EE),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFC168EE),
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Container(
        color: const Color(0xFFC168EE),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSettingItem(
                  context: context,
                  iconPath: 'assets/images/Globe.png',
                  title: loc.translate('language'),
                  subtitle: loc.translate(currentLangName),
                  onTap: () => _showLanguageDialog(context, localeProvider),
                ),
                const SizedBox(height: 12),
                _buildSettingItem(
                  context: context,
                  iconPath: 'assets/images/Trashcan.png',
                  title: loc.translate('cleanHistory'),
                  onTap: () => _showCleanHistoryDialog(context),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required BuildContext context,
    required String iconPath,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Image.asset(
                iconPath,
                width: 24,
                height: 24,
                color: const Color(0xFF0B0808),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.black54,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, LocaleProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('language')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _languages
                .map((lang) => ListTile(
              title: Text(lang['name']),
              onTap: () {
                provider.setLocale(lang['code'] as Locale);
                Navigator.pop(context);
              },
            ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showCleanHistoryDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.translate('cleanHistory')),
        content: Text(loc.translate('confirmCleanHistory')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              Provider.of<HistoryProvider>(context, listen: false).clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.translate('cleanHistorySuccess')),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(loc.translate('confirm')),
          ),
        ],
      ),
    );
  }
}