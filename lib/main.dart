// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
// import 'screens/main_screen.dart'; // We will now import LoginScreen
import 'screens/login_screen.dart'; // Import the new LoginScreen

// Student's Kitchen Color Palette
const Color skPrimaryGreen = Color(0xFF2D9A4B); // Chef Hat Green
const Color skSecondaryYellow = Color(0xFFFFD600); // Outline Yellow
const Color logoTextBlack = Color(0xFF000000);    // Text Black (as per your guideline for accent/warning)
const Color skBackgroundLight = Color(0xFFF4F4F4); // Light Grey Background
const Color skBackgroundWhite = Color(0xFFFFFFFF); // White Background (e.g., for Cards)
const Color skDarkText = Color(0xFF333333);       // Charcoal Grey for body text

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MessManagementApp());
}

class MessManagementApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final TextTheme baseTextTheme = Theme.of(context).textTheme;

    return MaterialApp(
      title: 'Student\'s Kitchen Mess',
      theme: ThemeData(
        primaryColor: skPrimaryGreen,
        scaffoldBackgroundColor: skBackgroundLight,
        colorScheme: ColorScheme(
          primary: skPrimaryGreen,
          onPrimary: skBackgroundWhite,
          secondary: skSecondaryYellow,
          onSecondary: logoTextBlack,      // Corrected: Used logoTextBlack
          surface: skBackgroundWhite,
          onSurface: skDarkText,
          background: skBackgroundLight,
          onBackground: skDarkText,
          error: Colors.red.shade700,
          onError: skBackgroundWhite,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: skPrimaryGreen,
          foregroundColor: skBackgroundWhite,
          elevation: 1.0,
          titleTextStyle: GoogleFonts.pacifico(
            fontSize: 24,
            fontWeight: FontWeight.normal,
            color: skBackgroundWhite,
          ),
          iconTheme: IconThemeData(color: skBackgroundWhite),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.pacifico(fontSize: 48, fontWeight: FontWeight.normal, color: logoTextBlack), // Using logoTextBlack for pure black accent
          displayMedium: GoogleFonts.pacifico(fontSize: 40, fontWeight: FontWeight.normal, color: logoTextBlack),
          displaySmall: GoogleFonts.pacifico(fontSize: 34, fontWeight: FontWeight.normal, color: logoTextBlack),

          headlineLarge: GoogleFonts.pacifico(fontSize: 28, fontWeight: FontWeight.normal, color: logoTextBlack),
          headlineMedium: GoogleFonts.pacifico(fontSize: 24, fontWeight: FontWeight.normal, color: logoTextBlack),
          headlineSmall: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: skDarkText),

          titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: skDarkText),
          titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.15),
          titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.1),

          bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400, color: skDarkText, letterSpacing: 0.5),
          bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: skDarkText, letterSpacing: 0.25),
          bodySmall: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: skDarkText, letterSpacing: 0.4),

          labelLarge: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.bold, color: skBackgroundWhite, letterSpacing: 1.25),
          labelMedium: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.5),
          labelSmall: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.5),
        ).apply(
          bodyColor: skDarkText,
          displayColor: logoTextBlack,
        ),
        cardTheme: CardThemeData(
          elevation: 2.0,
          color: skBackgroundWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: skPrimaryGreen,
            foregroundColor: skBackgroundWhite,
            textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            elevation: 2,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: skPrimaryGreen,
            textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: skSecondaryYellow,
          foregroundColor: logoTextBlack,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: skBackgroundWhite.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: skPrimaryGreen.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: skPrimaryGreen, width: 2),
          ),
          labelStyle: GoogleFonts.poppins(color: skPrimaryGreen),
          hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
          prefixIconColor: skPrimaryGreen.withOpacity(0.7),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: skPrimaryGreen.withOpacity(0.1),
          labelStyle: GoogleFonts.poppins(color: skPrimaryGreen, fontWeight: FontWeight.w500),
          selectedColor: skPrimaryGreen,
          secondarySelectedColor: skPrimaryGreen,
          secondaryLabelStyle: GoogleFonts.poppins(color: skBackgroundWhite, fontWeight: FontWeight.w500),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          iconTheme: IconThemeData(color: skPrimaryGreen, size: 18),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: skBackgroundWhite,
          selectedItemColor: skPrimaryGreen,
          unselectedItemColor: skDarkText.withOpacity(0.6),
          selectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 10),
          elevation: 5,
          type: BottomNavigationBarType.fixed,
        ),
        iconTheme: IconThemeData(
          color: skPrimaryGreen,
          size: 24.0,
        ),
        listTileTheme: ListTileThemeData(
          iconColor: skPrimaryGreen,
          tileColor: skBackgroundWhite,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey[300],
          thickness: 1,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LoginScreen(), // Updated to LoginScreen
      debugShowCheckedModeBanner: false,
    );
  }
}
