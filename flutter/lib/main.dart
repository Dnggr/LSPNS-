import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'secrets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('offline_reports');

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const LSPNSApp());
}

final supabase = Supabase.instance.client;

class LSPNSApp extends StatelessWidget {
  const LSPNSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LSPNS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: supabase.auth.currentSession != null
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
