// lib/screens/owner_profile_screen.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/app_settings_model.dart';

class OwnerProfileScreen extends StatefulWidget {
  final FirestoreService firestoreService;

  OwnerProfileScreen({required this.firestoreService});

  @override
  _OwnerProfileScreenState createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feeController = TextEditingController();
  double _currentStandardFee = 0.0; // To hold current fee from Firestore

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  void _saveStandardFee() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newFee = double.tryParse(_feeController.text);
      if (newFee != null && newFee > 0) {
        try {
          await widget.firestoreService.updateStandardMonthlyFee(newFee);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Standard monthly fee updated successfully!')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating fee: $e'), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid fee amount.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Owner Profile & Settings')),
      body: StreamBuilder<AppSettings>(
        stream: widget.firestoreService.getAppSettingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading settings: ${snapshot.error}'));
          }

          _currentStandardFee = snapshot.data?.standardMonthlyFee ?? 2000.0; // Default if null
          // Set initial value to controller only if it's empty or different
          // to avoid overriding user input during typing
          if (_feeController.text.isEmpty || double.tryParse(_feeController.text) != _currentStandardFee) {
            _feeController.text = _currentStandardFee.toStringAsFixed(0); // Or 2 for decimals
          }


          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: <Widget>[
                  Text(
                    'Manage Fee Rules',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _feeController,
                    decoration: InputDecoration(
                      labelText: 'Standard Monthly Fee (e.g., ₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a fee amount.';
                      }
                      if (double.tryParse(value) == null || double.parse(value) <= 0) {
                        return 'Please enter a valid positive amount.';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Save Standard Fee'),
                    onPressed: _saveStandardFee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  SizedBox(height: 30),
                  // You can add other owner profile settings here in the future
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
