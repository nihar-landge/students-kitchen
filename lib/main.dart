// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// This import is critical and assumes firebase_options.dart is in the lib/ folder
import 'firebase_options.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // This needs firebase_options.dart
  );
  runApp(MessManagementApp());
}

class MessManagementApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mess Management',
      theme: ThemeData(
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.teal[700],
            foregroundColor: Colors.white,
          ),
          cardTheme: CardThemeData( // Corrected to CardThemeData
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
