import 'package:flutter/material.dart';
// 新增：导入多语言工具类
import '../../i18n/app_localizations.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 新增：获取多语言实例
    final loc = AppLocalizations.of(context);

    return Container(
      color: const Color(0xFFC168EE),
      child: Center(
        // 关键修改：移除 const，替换文本为多语言翻译
        child: Text(
          loc.translate('workoutHistory'), // 替换固定英文为翻译
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}