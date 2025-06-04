// lib/screens/login_screen.dart
import 'dart:math' as math; // For random numbers
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// No longer need flutter_svg if only using JPG for logo here
// import 'package:flutter_svg/flutter_svg.dart';

import '../models/user_model.dart';
import 'main_screen.dart';

// Placeholder for color constants if not imported from main.dart
const Color skBasilGreen = Color(0xFF38761D);
const Color skDeepGreen = Color(0xFF2D9A4B);
const Color skBackgroundLight = Color(0xFFF7F7F7);
// Accent colors that might be used in the SVG or as fallbacks (can be removed if SVG is fully removed)
// const Color skLightGreenAccent1 = Color(0xFFE8F5E9);
// const Color skLightGreenAccent2 = Color(0xFFA5D6A7);
// const Color skDarkGreenAccent = Color(0xFF81C784);


class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passcodeController = TextEditingController();

  final String _ownerEmail = "admin@your-app.com";
  final String _guestEmail = "guest@your-app.com";

  UserRole _selectedRole = UserRole.guest;
  String? _errorMessage;
  bool _isLoading = false;

  // SVG Logo String is now removed
  // final String appLogoSvg = ''' ... ''';


  void _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      String enteredPassword = _passcodeController.text;
      String emailToUse;

      if (_selectedRole == UserRole.owner) {
        emailToUse = _ownerEmail;
      } else {
        emailToUse = _guestEmail;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailToUse,
          password: enteredPassword,
        );

        if (userCredential.user != null) {
          UserRole appRole = _selectedRole;
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(userRole: appRole),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String friendlyErrorMessage = "An error occurred. Please try again.";
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'INVALID_LOGIN_CREDENTIALS') {
          friendlyErrorMessage = "Incorrect email or password for the selected role.";
        } else if (e.code == 'wrong-password') {
          friendlyErrorMessage = "Incorrect password for the selected role.";
        } else if (e.code == 'invalid-email') {
          friendlyErrorMessage = "The email address for this role ($emailToUse) is not valid.";
        } else if (e.code == 'network-request-failed') {
          friendlyErrorMessage = "Network error. Please check your connection.";
        } else {
          friendlyErrorMessage = "Login failed. Please check your credentials and try again.";
          print('Firebase Auth Error: ${e.code} - ${e.message}');
        }
        if (mounted) {
          setState(() {
            _errorMessage = friendlyErrorMessage;
          });
        }
      } catch (e) {
        print('Generic Error during login: $e');
        if (mounted) {
          setState(() {
            _errorMessage = "An unexpected error occurred during login.";
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(
            painter: _LoginBackgroundPainter(
              primaryColor: skBasilGreen,
              lightGreen: skDeepGreen.withOpacity(0.4),
              lighterGreen: skBasilGreen.withOpacity(0.2),
              baseBackgroundColor: skBackgroundLight,
            ),
            child: Container(),
            size: Size.infinite,
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0), // Added vertical padding
              child: Column( // Main column for logo and then card
                mainAxisAlignment: MainAxisAlignment.center, // Center the column content
                children: [
                  // JPG Logo - MOVED HERE, ABOVE THE CARD
                  Container(
                    margin: EdgeInsets.only(bottom: 25.0), // Space between logo and card
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(120.0), // Increased for a more circular clip
                      child: Image.asset(
                        'assets/images/student_kitchen.png',
                        width: 120, // Slightly larger logo
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.food_bank_rounded, size: 80, color: theme.colorScheme.primary.withOpacity(0.7));
                        },
                      ),
                    ),
                  ),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                    color: theme.cardColor.withOpacity(0.95),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // Logo is now above the card
                            Text(
                              "Welcome to Student's Kitchen",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Mess Management",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            SizedBox(height: 30),
                            DropdownButtonFormField<UserRole>(
                              value: _selectedRole,
                              decoration: InputDecoration(
                                  labelText: 'Select Role',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  prefixIcon: Icon(
                                    _selectedRole == UserRole.owner ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                                    color: theme.colorScheme.primary,
                                  ),
                                  filled: true,
                                  fillColor: theme.scaffoldBackgroundColor.withOpacity(0.8)
                              ),
                              items: UserRole.values.map((UserRole role) {
                                return DropdownMenuItem<UserRole>(
                                  value: role,
                                  child: Text(
                                    role == UserRole.owner ? 'Owner (Admin)' : 'Guest',
                                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                  ),
                                );
                              }).toList(),
                              onChanged: (UserRole? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedRole = newValue;
                                    _errorMessage = null;
                                    _passcodeController.clear();
                                  });
                                }
                              },
                              style: theme.textTheme.bodyLarge,
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              controller: _passcodeController,
                              decoration: InputDecoration(
                                  labelText: 'Enter Password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                                  hintText: 'Password',
                                  filled: true,
                                  fillColor: theme.scaffoldBackgroundColor.withOpacity(0.8)
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password.';
                                }
                                return null;
                              },
                              style: theme.textTheme.bodyLarge,
                            ),
                            SizedBox(height: 15),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            SizedBox(height: 25),
                            _isLoading
                                ? Center(child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            ))
                                : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                elevation: 3,
                              ),
                              onPressed: _login,
                              child: Text('Login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the watercolor background
class _LoginBackgroundPainter extends CustomPainter {
  final Color primaryColor;
  final Color lightGreen;
  final Color lighterGreen;
  final Color baseBackgroundColor;

  _LoginBackgroundPainter({
    required this.primaryColor,
    required this.lightGreen,
    required this.lighterGreen,
    required this.baseBackgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint..color = baseBackgroundColor);

    final random = math.Random(123);

    paint.color = lighterGreen.withOpacity(0.3 + random.nextDouble() * 0.2);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + random.nextDouble() * 15);
    var path1 = Path();
    path1.moveTo(size.width * -0.1, size.height * 0.1);
    path1.quadraticBezierTo(size.width * 0.2, size.height * 0.5, size.width * 0.6, size.height * 0.3);
    path1.quadraticBezierTo(size.width * 1.1, size.height * 0.6, size.width * 0.7, size.height * 1.1);
    path1.quadraticBezierTo(size.width * 0.3, size.height * 1.2, size.width * -0.1, size.height * 0.8);
    path1.close();
    canvas.drawPath(path1, paint);

    paint.color = lightGreen.withOpacity(0.4 + random.nextDouble() * 0.2);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 25 + random.nextDouble() * 10);
    var path2 = Path();
    path2.moveTo(size.width * 0.5, size.height * -0.2);
    path2.quadraticBezierTo(size.width * 0.8, size.height * 0.2, size.width * 1.2, size.height * 0.4);
    path2.quadraticBezierTo(size.width * 0.9, size.height * 0.8, size.width * 0.4, size.height * 1.2);
    path2.quadraticBezierTo(size.width * 0.1, size.height * 0.7, size.width * 0.5, size.height * -0.2);
    path2.close();
    canvas.drawPath(path2, paint);

    paint.color = primaryColor.withOpacity(0.25 + random.nextDouble() * 0.15);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 15 + random.nextDouble() * 10);
    canvas.drawCircle(Offset(size.width * (0.7 + random.nextDouble() * 0.2), size.height * (0.2 + random.nextDouble() * 0.2)), size.width * (0.3 + random.nextDouble() * 0.15), paint);

    paint.color = lightGreen.withOpacity(0.35 + random.nextDouble() * 0.2);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 30 + random.nextDouble() * 10);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * (0.15 + random.nextDouble() * 0.2), size.height * (0.7 + random.nextDouble() * 0.2)), width: size.width * (0.5 + random.nextDouble() * 0.2), height: size.height * (0.4 + random.nextDouble() * 0.2)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
