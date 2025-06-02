// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for fetching roles (optional but good practice)

import '../models/user_model.dart'; // Your UserRole enum
import 'main_screen.dart'; // To navigate after login

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passcodeController = TextEditingController(); // This will now be the password field

  // --- Predefined emails for roles ---
  // Replace these with the actual emails you created in the Firebase Console
  final String _ownerEmail = "admin@your-app.com";
  final String _guestEmail = "guest@your-app.com";
  // ---

  UserRole _selectedRole = UserRole.guest; // Default to Guest
  String? _errorMessage;
  bool _isLoading = false; // For loading indicator

  void _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      String enteredPassword = _passcodeController.text;
      String emailToUse;

      if (_selectedRole == UserRole.owner) {
        emailToUse = _ownerEmail;
      } else { // Guest
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

        // Firebase Sign-In Successful!
        if (userCredential.user != null) {
          // The UserRole is determined by the dropdown selection in this specific UI.
          // If you had a more complex system where any Firebase user could be an owner or guest,
          // you would fetch their role from Firestore here using userCredential.user!.uid.
          // For this UI, the _selectedRole is already the intended application role.
          UserRole appRole = _selectedRole;

          // Example: If you wanted to verify the role from Firestore (good practice for robustness)
          // String uid = userCredential.user!.uid;
          // appRole = await _fetchAppRoleFromFirestore(uid, _selectedRole);


          if (!mounted) return; // Check if the widget is still in the tree
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(userRole: appRole),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String friendlyErrorMessage = "An error occurred. Please try again.";
        if (e.code == 'user-not-found') {
          friendlyErrorMessage = "This role account is not set up correctly in Firebase.";
          print('No user found for that email: $emailToUse. Ensure it is created in Firebase Auth.');
        } else if (e.code == 'wrong-password') {
          friendlyErrorMessage = "Incorrect password for the selected role.";
          print('Wrong password provided for $emailToUse.');
        } else if (e.code == 'invalid-email') {
          friendlyErrorMessage = "The email address for this role ($emailToUse) is not valid.";
          print('The email address $emailToUse is not valid.');
        } else if (e.code == 'network-request-failed') {
          friendlyErrorMessage = "Network error. Please check your connection.";
          print('Network error: ${e.message}');
        }
        else {
          friendlyErrorMessage = "Login failed. Please check your credentials and try again."; // More specific Firebase error
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

  // Optional: Function to fetch role from Firestore if you store roles there
  // This makes your system more flexible if a single Firebase account could have different app roles
  // or if you want to verify the selected role against a database record.
  // For your current UI, _selectedRole is likely sufficient as the source of truth for appRole.
  Future<UserRole> _fetchAppRoleFromFirestore(String uid, UserRole selectedRoleHint) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('user_roles').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        String? roleFromDb = (userDoc.data() as Map<String, dynamic>)['role'];
        if (roleFromDb == 'owner') return UserRole.owner;
        if (roleFromDb == 'guest') return UserRole.guest;
        // Fallback or error if role in DB doesn't match expected
        print("Warning: Role in Firestore ('$roleFromDb') does not match expected roles or is missing for UID: $uid. Using selected role as fallback.");
        return selectedRoleHint;
      } else {
        // If no role document exists, you might create one or default to the selected role.
        // This depends on your app's logic for managing roles.
        // For this specific UI, if the user authenticated, the selectedRole is the intended one.
        print("No role document found in Firestore for UID: $uid. Using selected role: $selectedRoleHint");
        // You might want to create a default role document here if this is the first login
        // await FirebaseFirestore.instance.collection('user_roles').doc(uid).set({
        //   'email': FirebaseAuth.instance.currentUser?.email, // Store email for reference
        //   'role': selectedRoleHint.toString().split('.').last // 'owner' or 'guest'
        // });
        return selectedRoleHint;
      }
    } catch (e) {
      print("Error fetching role from Firestore: $e. Defaulting to selected role.");
      return selectedRoleHint; // Fallback to the role selected in the UI
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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      "Welcome to\nStudent's Kitchen",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 30),
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Select Role',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        prefixIcon: Icon(
                          _selectedRole == UserRole.owner ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      items: UserRole.values.map((UserRole role) {
                        return DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(
                            role == UserRole.owner ? 'Owner (Admin)' : 'Guest',
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
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
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _passcodeController,
                      decoration: InputDecoration(
                        labelText: 'Enter Password', // Changed from Passcode to Password
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                        hintText: 'Password',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password.';
                        }
                        return null;
                      },
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                    SizedBox(height: 15),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(height: 15),
                    _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        textStyle: theme.textTheme.labelLarge,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: _login,
                      child: Text('Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
