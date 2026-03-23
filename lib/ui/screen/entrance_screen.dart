import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart';

class EntranceScreen extends StatelessWidget {
  const EntranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Screen size (used to calculate the size of the purple area)
    final screenSize = MediaQuery.of(context).size;

    // Automatically redirect to the home page after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(username: 'User'), // Pass the username
        ),
      );
    });

    return Scaffold(
      // Outer dark brown background
      backgroundColor: const Color(0xFFC168EE),
      body: Center(
        child: Container(
          //  purple area size: width 90% of screen, height 85% of screen
          width: screenSize.width * 0.9,
          height: screenSize.height * 0.85,
          // purple background
          color: const Color(0xFFDDA0DD),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/log.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),
              const Text(
                'WELCOME TO\nSMART FITNESS POD',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}