// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'owner_profile_screen.dart';
import 'archived_students_screen.dart'; // Import the new screen

class SettingsScreen extends StatelessWidget {
  final FirestoreService firestoreService; // Required
  final UserRole userRole;

  SettingsScreen({
    required this.firestoreService, // Make sure it's required
    required this.userRole,
    Key? key,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
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
                    builder: (context) => OwnerProfileScreen(firestoreService: firestoreService),
                  ),
                );
              },
            ),

          // View Archived Students - Only for Owner
          if (userRole == UserRole.owner)
            ListTile(
              leading: Icon(Icons.archive_outlined, color: Theme.of(context).colorScheme.primary),
              title: Text('View Archived Students'),
              subtitle: Text('Access records of past students'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArchivedStudentsScreen(
                      firestoreService: firestoreService,
                      userRole: userRole,
                    ),
                  ),
                );
              },
            ),
          if (userRole == UserRole.owner) Divider(),

          ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notification Preferences'), subtitle: Text('Set up alerts (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.backup_outlined), title: Text('Data Backup & Restore'), subtitle: Text('Export or import data (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.info_outline), title: Text('About App'), subtitle: Text('Version 1.2.1 (Role Access)'), onTap: () {}),
        ],
      ),
    );
  }
}
