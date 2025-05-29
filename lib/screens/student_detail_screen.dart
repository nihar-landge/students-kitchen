// lib/screens/student_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../utils/string_extensions.dart';

// Define the standard monthly fee here or fetch from a configuration service/document
const double STANDARD_MONTHLY_FEE = 2000.0;

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  final FirestoreService firestoreService;

  StudentDetailScreen({required this.studentId, required this.firestoreService});

  @override
  _StudentDetailScreenState createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _compensatoryDaysController = TextEditingController();
  final _compensatoryReasonController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  DateTime _selectedPaymentDate = DateTime.now();

  @override
  void dispose() {
    _compensatoryDaysController.dispose();
    _compensatoryReasonController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  double _calculateAmountPaidForCurrentCycle(Student student) {
    double amountPaid = 0.0;
    DateTime currentCycleStartDate = student.messStartDate;
    // A simple way: sum all payments that match the current cycle's start date.
    // More robust logic might be needed if payments can span multiple partial cycles
    // or if a cycle is defined by a start and end date in payment history.
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


  void _recordPaymentDialog(Student student) {
    _paymentAmountController.clear();
    _selectedPaymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext dlgContext) {
        return StatefulBuilder(builder: (stfContext, stfSetState) {
          return AlertDialog(
            title: Text('Record Payment for ${student.name}'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                TextFormField(
                    controller: _paymentAmountController,
                    decoration: InputDecoration(labelText: 'Amount Paid', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                    keyboardType: TextInputType.numberWithOptions(decimal: true)),
                SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('Payment Date: ${DateFormat.yMMMd().format(_selectedPaymentDate)}')),
                  TextButton.icon(
                      icon: Icon(Icons.calendar_today), label: Text('Change'),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                            context: dlgContext, initialDate: _selectedPaymentDate,
                            firstDate: DateTime(2020), lastDate: DateTime.now().add(Duration(days: 365)));
                        if (picked != null && picked != _selectedPaymentDate) {
                          stfSetState(() { _selectedPaymentDate = picked; });
                        }
                      })
                ]),
              ]),
            ),
            actions: <Widget>[
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dlgContext).pop()),
              ElevatedButton(
                  child: Text('Save Payment'),
                  onPressed: () async {
                    final amount = double.tryParse(_paymentAmountController.text);
                    if (amount == null || amount <= 0) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid positive amount.'), backgroundColor: Colors.red));
                      return;
                    }
                    List<PaymentHistoryEntry> updatedHistory = List.from(student.paymentHistory);
                    updatedHistory.add(PaymentHistoryEntry(
                        paymentDate: _selectedPaymentDate,
                        cycleStartDate: student.messStartDate, // Payment for current cycle
                        cycleEndDate: student.baseEndDate, // Base end of current cycle
                        paid: true,
                        amountPaid: amount
                    ));

                    try {
                      await widget.firestoreService.updateStudentPartial(student.id, {
                        'currentCyclePaid': true, // Or logic to determine if fully paid based on amount
                        'paymentHistory': updatedHistory.map((e) => e.toMap()).toList(),
                      });
                      if (!mounted) return;
                      Navigator.of(dlgContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment of $amount recorded for ${student.name}')));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving payment: $e'), backgroundColor: Colors.red));
                    }
                  }),
            ],
          );
        });
      },
    );
  }

  void _handlePaymentStatusChange(Student student) {
    // If marking as PAID, always go through record payment to ensure amount is captured
    // The currentCyclePaid status can be re-evaluated based on total paid vs standard fee
    _recordPaymentDialog(student);
    // The old "Mark as Unpaid" logic might need rethinking if you want to "void" a specific payment amount.
    // For now, currentCyclePaid is just a general flag; actual payment details are in history.
    // You could enhance this to check if STANDARD_MONTHLY_FEE is met.
  }

  void _addCompensatoryDaysDialog(Student student) {
    // ... (same as before, uses updateStudentPartial)
    _compensatoryDaysController.text = "0";
    _compensatoryReasonController.clear();
    showDialog(
      context: context,
      builder: (BuildContext dlgContext) {
        return AlertDialog(
          title: Text('Add Compensatory Days'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            TextField(controller: _compensatoryDaysController, decoration: InputDecoration(labelText: 'Number of Days to Add', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            SizedBox(height: 10),
            TextField(controller: _compensatoryReasonController, decoration: InputDecoration(labelText: 'Reason (Optional)', border: OutlineInputBorder()), maxLines: 2),
          ])),
          actions: <Widget>[
            TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dlgContext).pop()),
            ElevatedButton(
                child: Text('Add Days'),
                onPressed: () async {
                  final daysToAdd = int.tryParse(_compensatoryDaysController.text) ?? 0;
                  if (daysToAdd > 0) {
                    try {
                      await widget.firestoreService.updateStudentPartial(student.id, {'compensatoryDays': student.compensatoryDays + daysToAdd});
                      if (!mounted) return;
                      Navigator.of(dlgContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$daysToAdd compensatory days added for ${student.name}')));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding days: $e'), backgroundColor: Colors.red));
                    }
                  } else {
                    Navigator.of(dlgContext).pop();
                  }
                }),
          ],
        );
      },
    );
  }

  void _renewMessCycle(Student student) async {
    // ... (same as before, uses updateStudentPartial)
    double amountPaidForEndingCycle = _calculateAmountPaidForCurrentCycle(student);

    List<PaymentHistoryEntry> updatedHistory = List.from(student.paymentHistory);
    // Add an entry to finalize the ending cycle's payment status based on what was actually paid
    // This might duplicate if the last payment was already for this full cycle. Consider refining logic.
    // For now, this just records the state at renewal.
    bool wasEndingCycleConsideredPaid = amountPaidForEndingCycle >= STANDARD_MONTHLY_FEE; // Example logic

    updatedHistory.add(PaymentHistoryEntry(
        paymentDate: DateTime.now(), // Date of renewal processing
        cycleStartDate: student.messStartDate, // Old start date
        cycleEndDate: student.effectiveMessEndDate, // Old effective end date
        paid: wasEndingCycleConsideredPaid, // Use calculated or student.currentCyclePaid
        amountPaid: amountPaidForEndingCycle
    ));

    DateTime newStartDate = student.effectiveMessEndDate.add(Duration(days: 1));

    try {
      await widget.firestoreService.updateStudentPartial(student.id, {
        'messStartDate': Timestamp.fromDate(newStartDate),
        'compensatoryDays': 0,
        'currentCyclePaid': false, // New cycle starts as unpaid
        'paymentHistory': updatedHistory.map((e) => e.toMap()).toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mess cycle renewed for ${student.name}. Mark payment for new cycle.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renewing cycle: $e'), backgroundColor: Colors.red));
    }
  }

  void _showDeleteConfirmationDialog(Student student) {
    // ... (same as before, uses firestoreService.deleteStudent)
    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: Text('Confirm Delete'),
            content: Text('Are you sure you want to delete ${student.name} (${student.contactNumber})? This action cannot be undone.'),
            actions: <Widget>[
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Delete'),
                  onPressed: () async {
                    try {
                      await widget.firestoreService.deleteStudent(student.id);
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student.name} has been deleted.')));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red));
                    }
                  }),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Student?>(
      stream: widget.firestoreService.getStudentStream(widget.studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(title:Text("Loading...")), body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(title: Text("Error")), body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(appBar: AppBar(title: Text("Not Found")), body: Center(child: Text('Student not found.')));
        }

        final student = snapshot.data!;
        final double amountPaidForCurrentCycle = _calculateAmountPaidForCurrentCycle(student);
        final double remainingAmount = STANDARD_MONTHLY_FEE - amountPaidForCurrentCycle;
        // Update currentCyclePaid status based on if full amount is paid (optional, or keep it manual)
        // bool isCurrentCycleFullyPaid = remainingAmount <= 0;
        // if(student.currentCyclePaid != isCurrentCycleFullyPaid) {
        //   Future.microtask(() => widget.firestoreService.updateStudentPartial(student.id, {'currentCyclePaid': isCurrentCycleFullyPaid}));
        // }


        return WillPopScope(
          onWillPop: () async { Navigator.pop(context, true); return true; },
          child: Scaffold(
            appBar: AppBar(
              title: Text(student.name),
              actions: [
                IconButton(icon: Icon(Icons.delete_outline, color: Colors.redAccent[100]), tooltip: 'Delete Student', onPressed: () => _showDeleteConfirmationDialog(student)),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: <Widget>[
                  _buildDetailCard(context, title: 'Student Information', icon: Icons.person_pin_circle_outlined, children: [
                    _buildInfoRow('Name:', student.name),
                    _buildInfoRow('Contact (ID):', student.contactNumber),
                  ]),
                  SizedBox(height: 16),
                  _buildDetailCard(context, title: 'Mess Cycle Information', icon: Icons.calendar_today_outlined, children: [
                    _buildInfoRow('Cycle Start Date:', DateFormat.yMMMd().format(student.messStartDate)),
                    _buildInfoRow('Base End Date:', DateFormat.yMMMd().format(student.baseEndDate)),
                    _buildInfoRow('Compensatory Days:', '${student.compensatoryDays} days'),
                    _buildInfoRow('Effective End Date:', DateFormat.yMMMd().format(student.effectiveMessEndDate), isEmphasized: true),
                    _buildInfoRow('Days Remaining:', '${student.daysRemaining} days', isEmphasized: true),
                  ]),
                  SizedBox(height: 16),
                  _buildDetailCard(context, title: 'Payment (Current Cycle)', icon: Icons.monetization_on_outlined, children: [
                    _buildInfoRow('Standard Monthly Fee:', '₹${STANDARD_MONTHLY_FEE.toStringAsFixed(2)}'),
                    _buildInfoRow('Amount Paid this Cycle:', '₹${amountPaidForCurrentCycle.toStringAsFixed(2)}', isEmphasized: true),
                    _buildInfoRow('Remaining Amount:', '₹${remainingAmount.toStringAsFixed(2)}', isEmphasized: remainingAmount > 0),
                    SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Overall Cycle Status:', style: Theme.of(context).textTheme.titleMedium),
                      Chip( // This chip reflects the manually set currentCyclePaid flag.
                          label: Text(student.currentCyclePaid ? 'Marked PAID' : 'Marked NOT PAID'),
                          backgroundColor: student.currentCyclePaid ? Colors.green.shade100 : Colors.red.shade100,
                          labelStyle: TextStyle(color: student.currentCyclePaid ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold))
                    ]),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                        icon: Icon(Icons.payment), // Changed icon
                        label: Text('Record New Payment'), // Changed label
                        onPressed: () => _handlePaymentStatusChange(student),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
                    SizedBox(height: 10),
                    TextButton(onPressed: () {
                      if (student.paymentHistory.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No payment history for ${student.name}.'))); return;
                      }
                      showDialog(context: context, builder: (ctx) => AlertDialog(
                          title: Text("Payment History for ${student.name}"),
                          content: Container(width: double.maxFinite, child: ListView.builder(
                              shrinkWrap: true, itemCount: student.paymentHistory.length,
                              itemBuilder: (iCtx, idx) {
                                final entry = student.paymentHistory.reversed.toList()[idx];
                                return Card(margin: EdgeInsets.symmetric(vertical: 4), child: ListTile(
                                    title: Text("Cycle: ${DateFormat.yMMMd().format(entry.cycleStartDate)} - ${DateFormat.yMMMd().format(entry.cycleEndDate)}"),
                                    subtitle: Text("Paid on: ${DateFormat.yMMMd().format(entry.paymentDate)}\nStatus: ${entry.paid ? 'Paid' : 'Unpaid Entry'} - Amount: ₹${entry.amountPaid.toStringAsFixed(2)}"),
                                    leading: Icon(entry.paid ? Icons.check_circle : Icons.cancel, color: entry.paid ? Colors.green : Colors.red),
                                    isThreeLine: true));
                              })),
                          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text("Close"))]));
                    }, child: Text('View Full Payment History')),
                  ]),
                  SizedBox(height: 16),
                  _buildDetailCard(context, title: 'Attendance', icon: Icons.fact_check_outlined, children: [
                    // ... (Attendance Log viewing same as before)
                    TextButton(onPressed: () {
                      if (student.attendanceLog.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No attendance log for ${student.name}.'))); return;
                      }
                      showDialog(context: context, builder: (ctx) => AlertDialog(
                          title: Text("Attendance Log for ${student.name}"),
                          content: Container(width: double.maxFinite, child: ListView.builder(
                              shrinkWrap: true, itemCount: student.attendanceLog.length,
                              itemBuilder: (iCtx, idx) {
                                final entry = student.attendanceLog.reversed.toList()[idx];
                                return Card(margin: EdgeInsets.symmetric(vertical:4), child: ListTile(
                                  title: Text("${DateFormat.yMMMd().format(entry.date)} - ${entry.mealType.toString().split('.').last.capitalize()}"),
                                  subtitle: Text("Status: ${entry.status.toString().split('.').last.capitalize()}"),
                                  leading: Icon(entry.status == AttendanceStatus.present ? Icons.person_search_rounded : Icons.person_off_rounded, color: entry.status == AttendanceStatus.present ? Colors.green : Colors.orange),
                                ));
                              }
                          )),
                          actions: [TextButton(onPressed: ()=> Navigator.of(ctx).pop(), child: Text("Close"))]
                      ));
                    }, child: Text('View Attendance Log')),
                  ]),
                  SizedBox(height: 16),
                  _buildDetailCard(context, title: 'Manage Compensatory Days', icon: Icons.control_point_duplicate_outlined, children: [
                    // ... (Compensatory days same as before)
                    ElevatedButton.icon(icon: Icon(Icons.add_circle_outline), label: Text('Add Compensatory Days'), onPressed: () => _addCompensatoryDaysDialog(student)),
                    if (student.compensatoryDays > 0) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Current total: ${student.compensatoryDays} days added.', style: TextStyle(fontStyle: FontStyle.italic)))
                  ]),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                      icon: Icon(Icons.autorenew), label: Text('Renew Mess Cycle'), onPressed: () => _renewMessCycle(student),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 28),
              SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isEmphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: isEmphasized ? FontWeight.bold : FontWeight.normal, color: isEmphasized ? Colors.teal[700] : Colors.black87)),
        ],
      ),
    );
  }
}
