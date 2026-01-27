import 'package:flutter/material.dart';
import 'package:quietspot/screens/welcome_screen.dart';

void main() {
  runApp(const QuietSpotApp());
}

class QuietSpotApp extends StatelessWidget {
  const QuietSpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuietSpot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}


