// lib/screens/payments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';
import '../services/firestore_service.dart';
import '../utils/payment_manager.dart'; // Import PaymentManager

// MonthlyDueItem class is now in payment_manager.dart

class PaymentsScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final Function(Student) onViewStudent;
  final String? initialFilterOption;

  PaymentsScreen({
    Key? key,
    required this.firestoreService,
    required this.onViewStudent,
    this.initialFilterOption,
  }) : super(key: key);

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _filterOption = 'All Dues';
  bool _sortByHighestDues = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilterOption != null && (
        widget.initialFilterOption == 'Dues > 0' ||
            widget.initialFilterOption == 'Dues > 500' ||
            widget.initialFilterOption == 'Dues > 1000'
    )) {
      _filterOption = widget.initialFilterOption!;
    }
  }

  // REMOVED _calculateMonthlyDuesWithPaymentAllocation - Now in PaymentManager

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Dues Overview'),
        actions: [
          IconButton(
            icon: Icon(_sortByHighestDues ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: _sortByHighestDues ? "Sort: Highest Dues First" : "Sort: Lowest Dues First",
            onPressed: () {
              setState(() {
                _sortByHighestDues = !_sortByHighestDues;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: "Filter by Dues",
            initialValue: _filterOption,
            onSelected: (String value) {
              setState(() {
                _filterOption = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'All Dues', child: Text('Show All Students')),
              const PopupMenuItem<String>(value: 'Dues > 0', child: Text('Any Dues Remaining (> ₹0)')),
              const PopupMenuItem<String>(value: 'Dues > 500', child: Text('Dues > ₹500')),
              const PopupMenuItem<String>(value: 'Dues > 1000', child: Text('Dues > ₹1000')),
              const PopupMenuItem<String>(value: 'Fully Paid', child: Text('Show Fully Paid')),
            ],
          )
        ],
      ),
      body: StreamBuilder<AppSettings>(
        stream: widget.firestoreService.getAppSettingsStream(),
        builder: (context, appSettingsSnapshot) {
          if (!appSettingsSnapshot.hasData && appSettingsSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (appSettingsSnapshot.hasError) {
            return Center(child: Text('Error loading settings: ${appSettingsSnapshot.error}'));
          }
          final standardMonthlyFee = appSettingsSnapshot.data?.standardMonthlyFee ?? 2000.0;

          return StreamBuilder<List<Student>>(
            stream: widget.firestoreService.getStudentsStream(),
            builder: (context, studentSnapshot) {
              if (studentSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (studentSnapshot.hasError) {
                return Center(child: Text('Error loading students: ${studentSnapshot.error}'));
              }

              List<Student> allStudents = studentSnapshot.data ?? [];
              List<Map<String, dynamic>> studentsWithDues = [];

              for (var student in allStudents) {
                List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(student, standardMonthlyFee, DateTime.now());
                double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
                double totalPaidForAllMonths = duesList.fold(0.0, (sum, item) => sum + item.amountPaidForPeriod);
                studentsWithDues.add({
                  'student': student,
                  'totalRemaining': totalRemaining,
                  'totalPaid': totalPaidForAllMonths,
                });
              }

              List<Map<String, dynamic>> filteredStudentsWithDues = [];
              if (_filterOption == 'All Dues') {
                filteredStudentsWithDues = List.from(studentsWithDues);
              } else if (_filterOption == 'Dues > 0') {
                filteredStudentsWithDues = studentsWithDues.where((s) => (s['totalRemaining'] as double) > 0).toList();
              } else if (_filterOption == 'Dues > 500') {
                filteredStudentsWithDues = studentsWithDues.where((s) => (s['totalRemaining'] as double) > 500).toList();
              } else if (_filterOption == 'Dues > 1000') {
                filteredStudentsWithDues = studentsWithDues.where((s) => (s['totalRemaining'] as double) > 1000).toList();
              } else if (_filterOption == 'Fully Paid') {
                filteredStudentsWithDues = studentsWithDues.where((s) => (s['totalRemaining'] as double) <= 0).toList();
              }

              // Corrected sort implementation
              filteredStudentsWithDues.sort((a, b) {
                double duesA = a['totalRemaining'] as double;
                double duesB = b['totalRemaining'] as double;
                if (_sortByHighestDues) {
                  return duesB.compareTo(duesA); // Highest dues first
                }
                return duesA.compareTo(duesB); // Lowest dues first (or default)
              });

              return Column(
                children: [
                  // Corrected Padding widget
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Chip(
                        label: Text('Showing: $_filterOption (${filteredStudentsWithDues.length} students)'),
                        avatar: Icon(Icons.info_outline)
                    ),
                  ),
                  Expanded(
                    child: filteredStudentsWithDues.isEmpty
                        ? Center(child: Text('No students match the filter "$_filterOption".'))
                        : ListView.builder(
                        itemCount: filteredStudentsWithDues.length,
                        itemBuilder: (context, index) {
                          final studentData = filteredStudentsWithDues[index];
                          final student = studentData['student'] as Student;
                          final totalRemaining = studentData['totalRemaining'] as double;
                          final totalPaid = studentData['totalPaid'] as double;

                          String statusLabel;
                          Color statusColor;
                          IconData statusIcon;

                          if (totalRemaining <= 0) {
                            statusLabel = 'Fully Paid';
                            statusColor = Colors.green;
                            statusIcon = Icons.check_circle;
                          } else if (totalPaid > 0) {
                            statusLabel = 'Partially Paid (Due: ₹${totalRemaining.toStringAsFixed(2)})';
                            statusColor = Colors.orange.shade800;
                            statusIcon = Icons.hourglass_bottom_outlined;
                          } else {
                            statusLabel = 'Unpaid (Due: ₹${totalRemaining.toStringAsFixed(2)})';
                            statusColor = Colors.red.shade700;
                            statusIcon = Icons.error;
                          }

                          return Card(
                              color: totalRemaining > 0 && student.effectiveMessEndDate.isBefore(DateTime.now()) ? Colors.red.shade50 : (totalRemaining <=0 ? Colors.green.shade50 : null),
                              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                  leading: Icon(statusIcon, color: statusColor, size: 30),
                                  title: Text(student.name, style: TextStyle(fontWeight: FontWeight.w500)),
                                  subtitle: Text('Contact: ${student.contactNumber}\nService Ends: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}\nStatus: $statusLabel'),
                                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                                  isThreeLine: true,
                                  onTap: () => widget.onViewStudent(student)));
                        }),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
