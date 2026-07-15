import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'providers/migration_provider.dart';
import 'providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pivqwfqjpegekkyslvet.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpdnF3ZnFqcGVnZWtreXNsdmV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwNTM5ODUsImV4cCI6MjA5OTYyOTk4NX0.1j_fvfGDnPfwhv065-o8499zav3N89vUFi2spohhIDw',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, MigrationProvider>(
          create: (_) => MigrationProvider(),
          update: (_, auth, migrator) => migrator!..updateAuth(auth),
        ),
      ],
      child: const FlutterMigratorApp(),
    ),
  );
}
