// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart'; // Import UserRole
import 'owner_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();
  final UserRole userRole; // Add userRole parameter

  SettingsScreen({
    required this.userRole, // Add to constructor
    Key? key, // Added Key for StatelessWidget
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    // final bool isOwner = userRole == UserRole.owner; // Not directly used yet, but good for future

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          // Owner Profile & Fee Settings - Only for Owner
          if (userRole == UserRole.owner)
            ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Owner Profile & Fee Settings'),
              subtitle: Text('Manage your details and fee rules'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OwnerProfileScreen(firestoreService: _firestoreService),
                  ),
                );
              },
            ),
          // These are placeholders, so they can remain for guests or be hidden too
          ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notification Preferences'), subtitle: Text('Set up alerts (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.backup_outlined), title: Text('Data Backup & Restore'), subtitle: Text('Export or import data (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.info_outline), title: Text('About App'), subtitle: Text('Version 1.2.1 (Role Access)'), onTap: () {}),
        ],
      ),
    );
  }
}
