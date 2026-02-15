import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

await Supabase.initialize(
    url: 'https://laqcdxrupswdgfqcfbpz.supabase.co',   // 👈 paste your URL here
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxhcWNkeHJ1cHN3ZGdmcWNmYnB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNDM0MDcsImV4cCI6MjA4NjcxOTQwN30.KmMlhre2lefz1HLx1Sqv-0YWpsdfig1KesGdCuh44lA',                 // 👈 paste your anon key here
  );


  runApp(const SNASApp());
}

class SNASApp extends StatelessWidget {
  const SNASApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SNAS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.session != null) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
