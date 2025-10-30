import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

 @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // 计算图片尺寸：Start按钮宽度为屏幕60%，底部三个按钮为其1/5
    final startBtnWidth = screenWidth * 0.6;
    final bottomBtnWidth = startBtnWidth / 5;

    return Scaffold(
      backgroundColor: const Color(0xFF6A4A4A),
      body: Column(
        children: [
          // 顶部欢迎文字
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Text(
              'Welcome\n$username',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFFF00),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),

          const Spacer(flex: 2), // 顶部留白

          // 中间Start按钮
          Container(
            width: startBtnWidth,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFDDA0DD), // 紫色边框
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // Start按钮图片
                Image.asset(
                  'assets/images/Start.png',
                  width: startBtnWidth * 0.8, // 图片宽度为按钮的80%
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                // Start文字
                const Text(
                  'Start now',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                // 设备状态提示
                const Text(
                  'Device not found',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          const Spacer(flex: 3), // 中间留白

          // 底部三个按钮（Setting、Home、History）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Setting按钮
              _buildBottomButton(
                imagePath: 'assets/images/Setting.png',
                width: bottomBtnWidth,
                label: 'Setting',
              ),

              // Home按钮（上方有Square图标）
              Column(
                children: [
                  // Square小方框（位于Home图标上方）
                  Image.asset(
                    'assets/images/Square.png',
                    width: bottomBtnWidth * 0.6, // 小方框为Home图标的60%
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 5),
                  // Home按钮
                  _buildBottomButton(
                    imagePath: 'assets/images/Home.png',
                    width: bottomBtnWidth,
                    label: 'Home',
                  ),
                ],
              ),

              // History按钮
              _buildBottomButton(
                imagePath: 'assets/images/History.png',
                width: bottomBtnWidth,
                label: 'History',
              ),
            ],
          ),

          const SizedBox(height: 40), // 底部留白
        ],
      ),
    );
  }

  // 封装底部按钮组件（复用逻辑）
  Widget _buildBottomButton({
    required String imagePath,
    required double width,
    required String label,
  }) {
    return Column(
      children: [
        Image.asset(
          imagePath,
          width: width,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}