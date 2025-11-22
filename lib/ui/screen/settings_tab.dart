import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/app_localizations.dart';
import '../../providers/LocaleProvider.dart';
import 'package:provider/provider.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  // 修复：为列表和内部Map/Locale添加const，满足常量表达式要求
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
    // 获取当前选中的语言名称
    final currentLangName = _languages.firstWhere(
      (lang) => lang['code'] == localeProvider.currentLocale,
      orElse: () => _languages[0],
    )['name'];

    return Scaffold(
      // 顶部标题栏（与设计图一致的紫色背景）
      appBar: AppBar(
        title: Text(
          loc.translate('settings'),
          style: const TextStyle(
            color: Colors.white, // 白色文字
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFC168EE), // 设计图中的紫色
        elevation: 0, // 去除阴影
        // 沉浸式状态栏（可选）
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFC168EE),
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      
      // 主体内容（紫色背景，与设计图一致）
      body: Container(
        color: const Color(0xFFC168EE),
        child: ListView(
          children: [
            // 语言选择项（带 Globe.png 图标）
            _buildSettingItem(
              context: context,
              iconPath: 'assets/images/Globe.png', // 语言图标
              title: loc.translate('language'),
              subtitle: currentLangName, // 显示当前选中的语言
              onTap: () => _showLanguageDialog(context, localeProvider),
            ),

            // 清除历史记录项（带 Trashcan.png 图标）
            _buildSettingItem(
              context: context,
              iconPath: 'assets/images/Trashcan.png', // 垃圾桶图标
              title: loc.translate('cleanHistory'),
              onTap: () => _showCleanHistoryDialog(context),
            ),

            // 关于项
            _buildSettingItem(
              context: context,
              iconPath: 'assets/images/Setting.png', // 使用设置图标
              title: loc.translate('about'),
              onTap: () => _showAboutDialog(context, loc),
            ),
          ],
        ),
      ),
    );
  }

  // 通用设置项组件（统一样式）
  Widget _buildSettingItem({
    required BuildContext context,
    required String iconPath,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4), // 项之间的间距
      child: Material(
        color: Colors.white.withOpacity(0.2), // 半透明白色背景（设计图效果）
        borderRadius: BorderRadius.circular(8), // 圆角
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 左侧图标（Globe/Trashcan）
                Image.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  color: Colors.white, // 图标颜色为白色（与设计图匹配）
                ),
                const SizedBox(width: 16), // 图标与文字间距

                // 中间标题和子标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70, // 子标题稍浅
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 右侧箭头（表示可点击）
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 语言选择弹窗
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
                        provider.setLocale(lang['code'] as Locale); // 显式类型转换（可选）
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  // 清除历史记录确认弹窗
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
              // 这里添加清除历史记录的逻辑
              Navigator.pop(context);
              // 显示清除成功提示
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

  // 关于弹窗
  void _showAboutDialog(BuildContext context, AppLocalizations loc) {
    showAboutDialog(
      context: context,
      applicationName: loc.translate('appName'),
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Smart Fitness Pod',
    );
  }
}