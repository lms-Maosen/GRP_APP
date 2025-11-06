import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart';

class EntranceScreen extends StatelessWidget {
  const EntranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 屏幕尺寸（用于计算紫色区域大小）
    final screenSize = MediaQuery.of(context).size;

    // 3秒后自动跳转到首页（可修改秒数）
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(username: 'User'), // 传递用户名
        ),
      );
    });

    return Scaffold(
      // 外层深棕色背景（设计图中的外层边框色）
      backgroundColor: const Color(0xFFC168EE),
      body: Center(
        child: Container(
          // 紫色区域尺寸：宽度占屏幕90%，高度占屏幕85%
          width: screenSize.width * 0.9,
          height: screenSize.height * 0.85,
          // 紫色背景（与设计图一致）
          color: const Color(0xFFDDA0DD),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo图片
              Image.asset(
                'assets/images/log.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),
              // 文字内容
              const Text(
                'WELCOME TO\nSMART FITNESS POD',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  height: 1.2, // 调整行距
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}