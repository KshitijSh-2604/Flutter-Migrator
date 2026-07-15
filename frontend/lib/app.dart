import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/migrate_screen.dart';
import 'presentation/screens/history_screen.dart';
import 'presentation/screens/result_screen.dart';

class FlutterMigratorApp extends StatelessWidget {
  const FlutterMigratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    return MaterialApp(
      title: 'Flutter Migrator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: auth.user == null ? const AuthScreen() : const HomeScreen(),
      routes: {
        '/migrate': (context) => const MigrateScreen(),
        '/history': (context) => const HistoryScreen(),
        '/result': (context) => const ResultScreen(),
      },
    );
  }
}
