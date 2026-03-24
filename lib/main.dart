import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/home_page.dart';

// Fallback seed colour used on devices without dynamic colour support (pre-Android 12).
const _seedColor = Color(0xFF1A8FA6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final light =
            (lightDynamic ?? ColorScheme.fromSeed(seedColor: _seedColor))
                .harmonized();
        final dark =
            (darkDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: _seedColor,
                      brightness: Brightness.dark,
                    ))
                .harmonized();

        return MaterialApp(
          title: 'TravelAlarm',
          themeMode: ThemeMode.system,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: light,
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: dark,
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          home: const MyHomePage(title: 'TravelAlarm'),
        );
      },
    );
  }
}
