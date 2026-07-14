import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/migrate_screen.dart';
import 'presentation/screens/history_screen.dart';
import 'presentation/screens/result_screen.dart';

class FlutterMigratorApp extends StatelessWidget {
  const FlutterMigratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Migrator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/migrate': (context) => const MigrateScreen(),
        '/history': (context) => const HistoryScreen(),
        '/result': (context) => const ResultScreen(),
      },
    );
  }
}