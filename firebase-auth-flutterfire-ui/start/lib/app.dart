import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'chatbot_screen.dart'; // Import the new ChatbotScreen

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthGate(),
      routes: {
        '/chatbot': (context) => const ChatbotScreen(), // Ensure this route is correct
      },
    );
  }
}
