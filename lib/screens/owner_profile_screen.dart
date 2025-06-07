// lib/screens/owner_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  double _currentStandardFee = 0.0;
  // NEW: State variable for the effective date of the new fee
  DateTime _effectiveDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Set default effective date to the first of next month
    final now = DateTime.now();
    _effectiveDate = DateTime(now.year, now.month + 1, 1);
  }


  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  // NEW: Method to select the effective date for the fee change
  Future<void> _selectEffectiveDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _effectiveDate,
        firstDate: DateTime.now(), // Can't set a fee for the past
        lastDate: DateTime(2101));
    if (picked != null && picked != _effectiveDate) {
      setState(() {
        _effectiveDate = picked;
      });
    }
  }

  // MODIFIED: This function now saves a new fee entry to the history
  void _saveNewFee() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newFee = double.tryParse(_feeController.text);
      if (newFee != null && newFee > 0) {
        try {
          // Use the new service method
          await widget.firestoreService.addNewFee(newFee, _effectiveDate);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('New fee scheduled successfully!')),
          );
          _feeController.clear(); // Clear input after saving
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scheduling fee: $e'), backgroundColor: Colors.red),
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

          // MODIFIED: Get the current fee from the AppSettings model
          _currentStandardFee = snapshot.data?.currentStandardFee ?? 2000.0;

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
                  // Display the current fee
                  ListTile(
                    title: Text("Current Standard Fee", style: TextStyle(fontSize: 16)),
                    trailing: Text(
                      '₹${_currentStandardFee.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Divider(height: 30),

                  // Input for the new fee
                  TextFormField(
                    controller: _feeController,
                    decoration: InputDecoration(
                      labelText: 'New Fee Amount',
                      border: OutlineInputBorder(),
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a fee amount.';
                      }
                      final fee = double.tryParse(value);
                      if (fee == null || fee <= 0) {
                        return 'Please enter a valid positive amount.';
                      }
                      if (fee == _currentStandardFee) {
                        return 'New fee must be different from the current fee.';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),

                  // NEW: Date picker for the effective date
                  Row(children: <Widget>[
                    Expanded(child: Text('Effective From: ${DateFormat.yMMMd().format(_effectiveDate)}')),
                    TextButton.icon(
                        icon: Icon(Icons.calendar_today),
                        label: Text('Change Date'),
                        onPressed: () => _selectEffectiveDate(context)
                    )
                  ]),
                  SizedBox(height: 20),

                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('Schedule New Fee'),
                    // MODIFIED: Calls the new save function
                    onPressed: _saveNewFee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  SizedBox(height: 30),
                  // You can add a list view here to show the fee history from snapshot.data.feeHistory
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}