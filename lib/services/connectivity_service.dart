// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  bool _isConnected = true; // Assume connected initially
  bool get isConnected => _isConnected;

  ConnectivityService() {
    _checkInitialConnection();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _checkInitialConnection() async {
    List<ConnectivityResult> initialResults = await _connectivity.checkConnectivity();
    _updateConnectionStatus(initialResults);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // If the list of results contains 'none', it means no connection.
    // Otherwise, at least one type of connection (WiFi, Mobile, etc.) is active.
    bool currentlyConnected = !results.contains(ConnectivityResult.none);

    if (_isConnected != currentlyConnected) {
      _isConnected = currentlyConnected;
      notifyListeners(); // Notify widgets listening to this service
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}