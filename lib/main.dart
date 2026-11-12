import 'package:flutter/material.dart';
import 'screens/lock_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ExpenseApp());
}

/// The root widget of the AI Expense Analyzer application.
class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Expense Analyzer & Financial Assistant',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal.shade700,
          surface: const Color(0xFFF6F8FA),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Already authenticated in Firebase -> Go through Biometric Lock
            return const LockScreen();
          }
          // Not logged in -> Show Login Screen
          return const LoginScreen();
        },
      ),
    );
  }
}