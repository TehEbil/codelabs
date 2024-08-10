import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'screens/chatbot_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: const Color(0xFF8EC6C5),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF8EC6C5),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      routes: {
        '/chatbot': (context) => const ChatbotScreen(),
      },
    );
  }
}
