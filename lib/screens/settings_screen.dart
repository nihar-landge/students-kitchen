// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart'; // Import service
import 'owner_profile_screen.dart';      // Import new screen

class SettingsScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService(); // Instantiate or get from provider

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Owner Profile & Fee Settings'), // Updated title
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
          ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notification Preferences'), subtitle: Text('Set up alerts (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.backup_outlined), title: Text('Data Backup & Restore'), subtitle: Text('Export or import data (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.info_outline), title: Text('About App'), subtitle: Text('Version 1.2.0 (Fee Management)'), onTap: () {}),
        ],
      ),
    );
  }
}
