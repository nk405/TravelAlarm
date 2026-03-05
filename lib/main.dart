import 'package:flutter/material.dart';

import 'screens/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelAlarm',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3CCAD6),
          onPrimary: Color(0xFF042C33),
          secondary: Color(0xFF2BA6B6),
          onSecondary: Color(0xFF031E23),
          tertiary: Color(0xFFA6E7EE),
          onTertiary: Color(0xFF052930),
          surface: Color(0xFF0F1C22),
          onSurface: Color(0xFFE7F6F8),
          outline: Color(0xFF3B6570),
          outlineVariant: Color(0xFF223640),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B151A),
      ),
      home: const MyHomePage(title: 'TravelAlarm'),
    );
  }
}
