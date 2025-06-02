// lib/screens/settings_screen.dart
import 'package:flutter/material.dart'; // Corrected from .h to .dart
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'owner_profile_screen.dart';
import 'archived_students_screen.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // No longer needed if using PNGs for these icons

class SettingsScreen extends StatelessWidget {
  final FirestoreService firestoreService;
  final UserRole userRole;

  SettingsScreen({
    required this.firestoreService,
    required this.userRole,
    Key? key,
  }) : super(key: key);

  // Helper function to launch URLs
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Could not launch the URL
      // Optionally, show a SnackBar or print an error
      print('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // Owner Profile & Fee Settings - Only for Owner
          if (userRole == UserRole.owner)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Owner Profile & Fee Settings'),
              subtitle: const Text('Manage your details and fee rules'),
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
              title: const Text('View Archived Students'),
              subtitle: const Text('Access records of past students'),
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
          if (userRole == UserRole.owner) const Divider(),

          // About App
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About App'),
            subtitle: const Text('Version 1.2.1 (Role Access)'),
            onTap: () {},
          ),
          const Divider(),
        ],
      ),
      // Move the contact section to bottomNavigationBar
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Text(
              'CONECT!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.0,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LinkedIn Icon using PNG
              IconButton(
                icon: Image.asset(
                  'assets/icons/linkedin.png', // Path to your LinkedIn PNG
                  width: 24.0, // Adjust size as needed
                  height: 24.0, // Adjust size as needed
                ),
                onPressed: () {
                  _launchURL('https://www.linkedin.com/in/nihar-landge/'); // Replace with actual LinkedIn URL
                },
              ),
              const SizedBox(width: 8),
              // X (formerly Twitter) Icon using PNG
              IconButton(
                icon: Image.asset(
                  'assets/icons/x.png', // Path to your X (Twitter) PNG
                  width: 24.0, // Adjust size as needed
                  height: 24.0, // Adjust size as needed
                ),
                onPressed: () {
                  _launchURL('https://x.com/landge_nihar/'); // Replace with actual X (Twitter) URL
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }
}
