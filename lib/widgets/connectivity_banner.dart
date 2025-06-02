// lib/widgets/connectivity_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart'; // Adjust path if needed

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connectivityService = Provider.of<ConnectivityService>(context);

    if (connectivityService.isConnected) {
      return SizedBox.shrink(); // Return an empty box if connected
    }

    // If not connected, show the banner with the new style
    return Material( // Use Material for elevation (shadow) and theming
      elevation: 2.0, // Add a subtle shadow
      child: Container(
        width: double.infinity,
        // Light, creamy off-white or very light beige background
        color: Color(0xFFFFF8E1), // Example: Colors.amber[50] or a custom light beige
        padding: EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 16.0,
        ),
        child: SafeArea( // Ensures content is not obscured by notches, status bars etc.
          bottom: false,
          left: true,
          right: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start, // Align icon to the start
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined, // Cloud with a slash or similar
                color: Colors.grey[700], // A neutral dark grey for the icon
                size: 20.0,
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  'You are offline. Changes will sync once reconnected.',
                  style: TextStyle(
                    color: Colors.grey[800], // Darker grey for better readability on light bg
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500, // Slightly bolder
                  ),
                  // textAlign: TextAlign.center, // Center if you prefer, or start
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
