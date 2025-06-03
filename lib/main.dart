// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
// import 'package:google_fonts/google_fonts.dart'; // Can be removed if not used

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/connectivity_service.dart'; // <<<--- ADD THIS IMPORT
import 'widgets/connectivity_banner.dart';

// --- New Color Palette ---
const Color skBasilGreen = Color(0xFF38761D); // A fresh, basil-like green
const Color skDeepGreen = Color(0xFF2D9A4B);   // Your original primary, still good

// Accent Colors (Warm Tones)
const Color skAmberYellow = Color(0xFFFFC107); // Warm amber/yellow
const Color skTomatoRed = Color(0xFFFF6347);   // Tomato red for highlights/errors
const Color skTerracotta = Color(0xFFE2725B);  // A warmer, earthy red option

// Neutral & Background Colors
const Color skBackgroundLight = Color(0xFFF7F7F7); // Slightly off-white for background
const Color skBackgroundWhite = Color(0xFFFFFFFF); // For Cards and surfaces
const Color skDarkText = Color(0xFF2F2F2F);        // Darker charcoal for better contrast
const Color skLightText = Color(0xFF6C6C6C);       // Lighter grey for subtitles
const Color skPureBlack = Color(0xFF000000); // For text that needs to be pure black

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MessManagementApp());
}

class MessManagementApp extends StatelessWidget {
  const MessManagementApp({super.key});
  @override
  Widget build(BuildContext context) {
    // final TextTheme baseTextTheme = Theme.of(context).textTheme; // Not strictly needed for this correction


    // You can choose which green to use as the main primary color for the theme.
    // Let's use skBasilGreen as the primary for this example.
    final Color appPrimaryColor = skBasilGreen;
    final Color appSecondaryColor = skAmberYellow;
    final Color appErrorColor = skTomatoRed; // Good choice for error color

    return ChangeNotifierProvider(
      create: (context) => ConnectivityService(),
      child: MaterialApp(
        title: 'Student\'s Kitchen Mess',
        theme: ThemeData(
          // ... your existing theme data ...
          primaryColor: appPrimaryColor,
          scaffoldBackgroundColor: skBackgroundLight,
          colorScheme: ColorScheme(
            primary: appPrimaryColor,
            onPrimary: skBackgroundWhite,
            secondary: appSecondaryColor,
            onSecondary: skDarkText,
            surface: skBackgroundWhite,
            onSurface: skDarkText,
            error: appErrorColor,
            onError: skBackgroundWhite,
            brightness: Brightness.light,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: appPrimaryColor,
            foregroundColor: skBackgroundWhite,
            elevation: 1.0,
            titleTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              color: skBackgroundWhite,
            ),
            iconTheme: IconThemeData(color: skBackgroundWhite),
          ),
          textTheme: TextTheme(
            displayLarge: TextStyle(fontFamily: 'Inter', fontSize: 48, color: skDarkText),
            displayMedium: TextStyle(fontFamily: 'Inter', fontSize: 40, color: skDarkText),
            displaySmall: TextStyle(fontFamily: 'Inter', fontSize: 34, color: skDarkText),
            headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 28, color: skDarkText),
            headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 24, color: skDarkText),
            headlineSmall: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w600, color: skDarkText),
            titleLarge: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600, color: skDarkText),
            titleMedium: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.15),
            titleSmall: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.1),
            bodyLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400, color: skDarkText, letterSpacing: 0.5),
            bodyMedium: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w400, color: skDarkText, letterSpacing: 0.25),
            bodySmall: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400, color: skLightText, letterSpacing: 0.4),
            labelLarge: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.bold, color: skBackgroundWhite, letterSpacing: 1.25),
            labelMedium: TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.5),
            labelSmall: TextStyle(fontFamily: 'Montserrat', fontSize: 11, fontWeight: FontWeight.w500, color: skLightText, letterSpacing: 0.5),
          ).apply(
            bodyColor: skDarkText,
            displayColor: skDarkText,
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
              backgroundColor: appPrimaryColor,
              foregroundColor: skBackgroundWhite,
              textStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 15),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              elevation: 2,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: appPrimaryColor,
              textStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: appSecondaryColor,
            foregroundColor: skDarkText,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: skBackgroundWhite.withAlpha((255 * 0.8).round()),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: appPrimaryColor.withAlpha(128)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: appPrimaryColor, width: 2),
            ),
            labelStyle: TextStyle(fontFamily: 'Poppins', color: appPrimaryColor),
            hintStyle: TextStyle(fontFamily: 'Poppins', color: skLightText),
            prefixIconColor: appPrimaryColor.withAlpha((255 * 0.7).round()),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: appPrimaryColor.withAlpha((255 * 0.1).round()),
            labelStyle: TextStyle(fontFamily: 'Poppins', color: appPrimaryColor, fontWeight: FontWeight.w500),
            selectedColor: appPrimaryColor,
            secondarySelectedColor: appPrimaryColor,
            secondaryLabelStyle: TextStyle(fontFamily: 'Poppins', color: skBackgroundWhite, fontWeight: FontWeight.w500),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            iconTheme: IconThemeData(color: appPrimaryColor, size: 18),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: skBackgroundWhite,
            selectedItemColor: appPrimaryColor,
            unselectedItemColor: skDarkText.withAlpha((255 * 0.6).round()),
            selectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontSize: 10),
            elevation: 5,
            type: BottomNavigationBarType.fixed,
          ),
          iconTheme: IconThemeData(
            color: appPrimaryColor,
            size: 24.0,
          ),
          listTileTheme: ListTileThemeData(
            iconColor: appPrimaryColor,
            tileColor: skBackgroundWhite,
          ),
          dividerTheme: DividerThemeData(
            color: Colors.grey[300],
            thickness: 1,
          ),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: LoginScreen(),
        // Use the builder to inject the ConnectivityBanner
        builder: (context, child) {
          // The 'child' here is the widget tree being built by MaterialApp (e.g., LoginScreen or MainScreen)
          return Column(
            children: [
              ConnectivityBanner(), // Your banner will always be at the top
              Expanded(child: child!), // The rest of your app below the banner
            ],
          );
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}