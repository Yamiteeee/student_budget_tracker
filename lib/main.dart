// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_budget_tracker/firebase_options.dart';
import 'package:student_budget_tracker/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _userId;
  ThemeMode _themeMode = ThemeMode.light; // Default to light mode

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _userId = user?.uid;
        });
      }
    });

    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
        print("Signed in anonymously");
      } catch (e) {
        print("Failed to sign in anonymously: $e");
      }
    }
  }

  // Toggles between light and dark theme
  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Budget Tracker',
      debugShowCheckedModeBanner: false, // Removed debug banner
      themeMode: _themeMode, // Use the theme mode state
      theme: ThemeData( // --- LIGHT THEME ---
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.light, // Explicitly light brightness
        scaffoldBackgroundColor: const Color(0xFFF0F0F0), // Light grey, not pure white
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple, // AppBar color for light theme
          foregroundColor: Colors.white,
        ),
        cardColor: const Color(0xFFE0E0E0), // Slightly darker card for light theme
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87), // Dark text for light theme
          bodyMedium: TextStyle(color: Colors.black54),
          titleLarge: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black87),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurpleAccent,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[200], // Lighter fill for light theme inputs
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2.0),
          ),
          labelStyle: const TextStyle(color: Colors.black54),
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.deepPurpleAccent,
          textTheme: ButtonTextTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),
      darkTheme: ThemeData( // --- DARK THEME ---
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
        ),
        cardColor: Colors.grey[800],
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurpleAccent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[700],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2.0),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.deepPurpleAccent,
          textTheme: ButtonTextTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),
      home: _userId == null
          ? const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing user and Firebase...'),
            ],
          ),
        ),
      )
          : HomeScreen(
        userId: _userId!,
        toggleThemeMode: _toggleThemeMode, // Pass the theme toggle function
      ),
    );
  }
}