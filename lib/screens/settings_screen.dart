// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          ListTile(leading: Icon(Icons.person_outline), title: Text('Owner Profile'), subtitle: Text('Manage your details (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notification Preferences'), subtitle: Text('Set up alerts (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.backup_outlined), title: Text('Data Backup & Restore'), subtitle: Text('Export or import data (Not Implemented)'), onTap: () {}),
          ListTile(leading: Icon(Icons.info_outline), title: Text('About App'), subtitle: Text('Version 1.1.0 (Firestore Integrated)'), onTap: () {}),
        ],
      ),
    );
  }
}
