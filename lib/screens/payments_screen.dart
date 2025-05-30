// lib/screens/payments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';
import '../services/firestore_service.dart';

class PaymentsScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final Function(Student) onViewStudent;
  final String? initialFilterOption; // New property to accept initial filter

  PaymentsScreen({
    Key? key, // Added Key
    required this.firestoreService,
    required this.onViewStudent,
    this.initialFilterOption,
  }) : super(key: key); // Pass key to super

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _filterOption = 'All';
  bool _sortByHighestDues = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilterOption != null) {
      _filterOption = widget.initialFilterOption!;
    }
  }

  double _calculateAmountPaidForCurrentCycle(Student student) {
    double amountPaid = 0.0;
    DateTime currentCycleStartDate = student.messStartDate;
    for (var entry in student.paymentHistory) {
      if (entry.paid &&
          entry.cycleStartDate.year == currentCycleStartDate.year &&
          entry.cycleStartDate.month == currentCycleStartDate.month &&
          entry.cycleStartDate.day == currentCycleStartDate.day) {
        amountPaid += entry.amountPaid;
      }
    }
    return amountPaid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Dues Overview'),
        actions: [
          IconButton(
            icon: Icon(_sortByHighestDues ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: _sortByHighestDues ? "Sort by Lowest Dues" : "Sort by Highest Dues",
            onPressed: () {
              setState(() {
                _sortByHighestDues = !_sortByHighestDues;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: "Filter by Dues",
            initialValue: _filterOption, // Set initial value for PopupMenuButton
            onSelected: (String value) {
              setState(() {
                _filterOption = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'All', child: Text('Show All Students')),
              const PopupMenuItem<String>(value: 'Dues > 0', child: Text('Show Dues > ₹0')),
              const PopupMenuItem<String>(value: 'Dues > 500', child: Text('Show Dues > ₹500')),
              const PopupMenuItem<String>(value: 'Dues > 1000', child: Text('Show Dues > ₹1000')),
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
              List<Student> filteredStudents = [];

              Map<String, double> studentDues = {};
              for (var student in allStudents) {
                double amountPaid = _calculateAmountPaidForCurrentCycle(student);
                studentDues[student.id] = standardMonthlyFee - amountPaid;
              }

              if (_filterOption == 'All') {
                filteredStudents = List.from(allStudents);
              } else if (_filterOption == 'Dues > 0') {
                filteredStudents = allStudents.where((s) => (studentDues[s.id] ?? 0) > 0).toList();
              } else if (_filterOption == 'Dues > 500') {
                filteredStudents = allStudents.where((s) => (studentDues[s.id] ?? 0) > 500).toList();
              } else if (_filterOption == 'Dues > 1000') {
                filteredStudents = allStudents.where((s) => (studentDues[s.id] ?? 0) > 1000).toList();
              }

              filteredStudents.sort((a, b) {
                double duesA = studentDues[a.id] ?? 0;
                double duesB = studentDues[b.id] ?? 0;
                if (_sortByHighestDues) {
                  return duesB.compareTo(duesA);
                }
                return duesA.compareTo(duesB);
              });

              return Column(
                children: [
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Chip(label: Text('Filter: $_filterOption (${filteredStudents.length} students)'), avatar: Icon(Icons.info_outline))),
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? Center(child: Text('No students match the filter "$_filterOption".'))
                        : ListView.builder(
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final remainingAmount = studentDues[student.id] ?? 0;
                          bool isOverdueAndUnpaid = student.effectiveMessEndDate.isBefore(DateTime.now()) && remainingAmount > 0;

                          String statusText;
                          Color statusColor;
                          if (remainingAmount <= 0) {
                            statusText = '₹0.00 remaining (Paid)';
                            statusColor = Colors.green;
                          } else {
                            statusText = '₹${remainingAmount.toStringAsFixed(2)} remaining';
                            statusColor = isOverdueAndUnpaid ? Colors.red.shade700 : Colors.orange;
                          }

                          return Card(
                              color: isOverdueAndUnpaid ? Colors.red.shade50 : (remainingAmount <=0 ? Colors.green.shade50 : null),
                              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                  leading: Icon(
                                    remainingAmount <= 0 ? Icons.check_circle_outline : Icons.error_outline,
                                    color: statusColor,
                                    size: 30,
                                  ),
                                  title: Text(student.name, style: TextStyle(fontWeight: FontWeight.w500)),
                                  subtitle: Text('Contact: ${student.contactNumber}\nEnds: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}\nStatus: $statusText'),
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
