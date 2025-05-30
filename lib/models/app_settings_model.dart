// lib/models/app_settings_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

const String APP_SETTINGS_DOC_ID = "app_config"; // Fixed document ID for app settings

class AppSettings {
  final double standardMonthlyFee;

  AppSettings({required this.standardMonthlyFee});

  factory AppSettings.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    return AppSettings(
      standardMonthlyFee: (data['standardMonthlyFee'] as num?)?.toDouble() ?? 2000.0, // Default if not set
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'standardMonthlyFee': standardMonthlyFee,
    };
  }
}
