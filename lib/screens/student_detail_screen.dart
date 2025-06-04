// lib/screens/student_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';
import '../models/user_model.dart'; // Import UserRole
import '../services/firestore_service.dart';
import '../utils/payment_manager.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  final FirestoreService firestoreService;
  final UserRole userRole;

  StudentDetailScreen({
    required this.studentId,
    required this.firestoreService,
    required this.userRole,
  });

  @override
  _StudentDetailScreenState createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _compensatoryDaysController = TextEditingController();
  final _compensatoryReasonController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  DateTime _selectedPaymentDate = DateTime.now();
  DateTime? _paymentForPeriodStart;
  DateTime? _manualServiceStartDate; // For manual period start dialog

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

  void _recordPaymentDialog(Student student, List<MonthlyDueItem> billingPeriodsFromManager, double standardMonthlyFee) {
    if (widget.userRole == UserRole.guest) return;

    _paymentAmountController.clear();
    _selectedPaymentDate = DateTime.now();
    _paymentForPeriodStart = null;

    List<MonthlyDueItem> selectablePeriods = List.from(billingPeriodsFromManager);

    // If no billing periods exist yet (e.g., student just added, service starts today/future)
    // and original service start date is not far in the past (e.g. within a day from now or in future)
    if (selectablePeriods.isEmpty && student.originalServiceStartDate.isAfter(DateTime.now().subtract(Duration(days:1)))) {
      DateTime firstPeriodStart = student.originalServiceStartDate;
      String displaySuffix = (firstPeriodStart.day != 1) ? " (from ${DateFormat.d().format(firstPeriodStart)})" : "";
      // Calculate end of the month for the firstPeriodStart
      DateTime firstPeriodEnd = DateTime(firstPeriodStart.year, firstPeriodStart.month + 1, 0);
      // Ensure firstPeriodEnd does not exceed the student's effective mess end date
      if (firstPeriodEnd.isAfter(student.effectiveMessEndDate)) {
        firstPeriodEnd = student.effectiveMessEndDate;
      }
      selectablePeriods.add(MonthlyDueItem(
          monthYearDisplay: DateFormat('MMMM yy').format(firstPeriodStart) + displaySuffix,
          periodStartDate: firstPeriodStart,
          periodEndDate: firstPeriodEnd, // Use calculated end of month
          feeDueForPeriod: standardMonthlyFee,
          amountPaidForPeriod: 0.0 // Initially 0 for a new period
      ));
    }
    // Fallback if still no selectable periods (e.g., for a very old student record with no activity)
    if (selectablePeriods.isEmpty) {
      DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      selectablePeriods.add(MonthlyDueItem(
          monthYearDisplay: DateFormat('MMMM yy').format(currentMonth),
          periodStartDate: currentMonth,
          periodEndDate: DateTime(currentMonth.year, currentMonth.month + 1, 0),
          feeDueForPeriod: standardMonthlyFee,
          amountPaidForPeriod: 0.0
      ));
    }


    showDialog(
      context: context,
      builder: (BuildContext dlgContext) {
        return StatefulBuilder(builder: (stfContext, stfSetState) {
          // Filter for periods that actually have dues remaining
          final List<MonthlyDueItem> periodsForDropdown = selectablePeriods.where((due) => due.remainingForPeriod > 0).toList();

          // Auto-select the first available period if _paymentForPeriodStart is null or not in the list
          if (_paymentForPeriodStart != null && !periodsForDropdown.any((p) => p.periodStartDate.isAtSameMomentAs(_paymentForPeriodStart!))) {
            _paymentForPeriodStart = periodsForDropdown.isNotEmpty ? periodsForDropdown.first.periodStartDate : null;
          } else if (_paymentForPeriodStart == null && periodsForDropdown.isNotEmpty) {
            _paymentForPeriodStart = periodsForDropdown.first.periodStartDate;
          }

          return AlertDialog(
            title: Text('Record Payment for ${student.name}'),
            content: Container( // Added Container to control dialog width if necessary
              width: MediaQuery.of(dlgContext).size.width * 0.9, // Make dialog wider
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  TextFormField(
                      controller: _paymentAmountController,
                      decoration: InputDecoration(labelText: 'Amount Paid', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                      keyboardType: TextInputType.numberWithOptions(decimal: true)),
                  SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Text('Payment Date: ${DateFormat.yMMMd().format(_selectedPaymentDate)}')),
                    TextButton.icon(
                        icon: Icon(Icons.calendar_today),
                        label: Text('Change'),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                              context: dlgContext, initialDate: _selectedPaymentDate,
                              firstDate: DateTime(2020), lastDate: DateTime.now().add(Duration(days: 365))); // Allow future payment dates
                          if (picked != null && picked != _selectedPaymentDate) {
                            stfSetState(() { _selectedPaymentDate = picked; });
                          }
                        })
                  ]),
                  SizedBox(height: 16),
                  if (periodsForDropdown.isNotEmpty)
                    DropdownButtonFormField<DateTime>(
                      decoration: InputDecoration(labelText: "Payment For Period Starting", border: OutlineInputBorder()),
                      value: _paymentForPeriodStart,
                      isExpanded: true,
                      items: periodsForDropdown
                          .map((dueItem) => DropdownMenuItem<DateTime>(
                        value: dueItem.periodStartDate,
                        child: Text(
                          "${dueItem.monthYearDisplay} (Due: ₹${dueItem.remainingForPeriod.toStringAsFixed(0)})",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                          .toList(),
                      onChanged: (DateTime? newValue) {
                        stfSetState(() { _paymentForPeriodStart = newValue; });
                      },
                      validator: (value) => value == null ? 'Please select a period' : null,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("No periods with outstanding dues available for selection, or all periods are fully paid.", style: TextStyle(fontStyle: FontStyle.italic)),
                    ),
                ]),
              ),
            ),
            actions: <Widget>[
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dlgContext).pop()),
              ElevatedButton(
                  child: Text('Save Payment'),
                  onPressed: () async {
                    final amount = double.tryParse(_paymentAmountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid positive amount.'), backgroundColor: Colors.red));
                      return;
                    }
                    if (_paymentForPeriodStart == null) {
                      // This case might happen if periodsForDropdown was empty
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No payment period selected or available. Please ensure a period with dues is chosen.'), backgroundColor: Colors.red));
                      return;
                    }

                    List<PaymentHistoryEntry> updatedHistory = List.from(student.paymentHistory);
                    // Find the details of the period being paid for
                    MonthlyDueItem paidForPeriodDetails = selectablePeriods.firstWhere(
                            (p) => p.periodStartDate.isAtSameMomentAs(_paymentForPeriodStart!),
                        orElse: () => MonthlyDueItem( // Fallback, should ideally not be hit if _paymentForPeriodStart is valid
                            monthYearDisplay: "Error: Period Not Found",
                            periodStartDate: _paymentForPeriodStart!,
                            periodEndDate: DateTime(_paymentForPeriodStart!.year, _paymentForPeriodStart!.month+1,0), // Default end
                            feeDueForPeriod: 0 // Default fee
                        )
                    );

                    updatedHistory.add(PaymentHistoryEntry(
                        paymentDate: _selectedPaymentDate,
                        cycleStartDate: paidForPeriodDetails.periodStartDate, // Use start date of the selected due item
                        cycleEndDate: paidForPeriodDetails.periodEndDate,   // Use end date of the selected due item
                        paid: true, // Mark as paid
                        amountPaid: amount
                    ));

                    // Recalculate dues to determine the new currentCyclePaid flag
                    final AppSettings appSettings = await widget.firestoreService.getAppSettingsStream().first;
                    List<MonthlyDueItem> duesAfterPayment = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
                        Student( // Create a temporary student object with the new payment history for calculation
                            id: student.id, name: student.name,
                            messStartDate: student.messStartDate,
                            originalServiceStartDate: student.originalServiceStartDate,
                            compensatoryDays: student.compensatoryDays,
                            currentCyclePaid: student.currentCyclePaid, // Old value, will be updated based on calculation
                            attendanceLog: student.attendanceLog,
                            paymentHistory: updatedHistory, // Use the updated history
                            isArchived: student.isArchived
                        ),
                        appSettings.standardMonthlyFee,
                        DateTime.now() // Calculate up to today
                    );
                    double totalRemainingAfterThisPayment = duesAfterPayment.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
                    // A student's "current cycle" is considered paid if their total outstanding dues are zero or less.
                    bool newCurrentCyclePaidFlag = totalRemainingAfterThisPayment <= 0;


                    try {
                      await widget.firestoreService.updateStudentPartial(student.id, {
                        'currentCyclePaid': newCurrentCyclePaidFlag, // Update based on total remaining dues
                        'paymentHistory': updatedHistory.map((e) => e.toMap()).toList(),
                      });
                      if (!mounted) return;
                      Navigator.of(dlgContext).pop(); // Close the dialog
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment of ₹$amount recorded for ${student.name}')));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving payment: $e'), backgroundColor: Colors.red,));
                    }
                  }),
            ],
          );
        });
      },
    );
  }

  void _addCompensatoryDaysDialog(Student student) {
    if (widget.userRole == UserRole.guest) return;

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
                    if (daysToAdd < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot add negative compensatory days.'), backgroundColor: Colors.orange));
                    } else {
                      Navigator.of(dlgContext).pop(); // If 0 days, just close
                    }
                  }
                }),
          ],
        );
      },
    );
  }

  // Renamed to reflect it's the "Automatic" continuation
  void _startNextServicePeriodAuto(Student student) async {
    if (widget.userRole == UserRole.guest) return;
    if (student.isArchived) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot start new period for an archived student.'), backgroundColor: Colors.orange));
      return;
    }

    // The new start date is the day after the current effective end date.
    DateTime newStartDateForStudent = student.effectiveMessEndDate.add(Duration(days: 1));
    DateTime today = DateTime.now();
    DateTime firstOfThisMonth = DateTime(today.year, today.month, 1);

    // If the calculated new start date is in a past month (and not the current month),
    // adjust it to the first day of the current month.
    // This prevents starting a service period too far in the past if a student's record wasn't updated for a while.
    if (newStartDateForStudent.isBefore(firstOfThisMonth) &&
        !(newStartDateForStudent.year == firstOfThisMonth.year && newStartDateForStudent.month == firstOfThisMonth.month)) {
      newStartDateForStudent = firstOfThisMonth;
    }
    // Also, if the calculated new start date is still before today (but in the current month),
    // it might make sense to start it from today. However, the current logic starts from firstOfThisMonth
    // or the day after effectiveMessEndDate. This behavior is retained.

    try {
      await widget.firestoreService.updateStudentPartial(student.id, {
        'messStartDate': Timestamp.fromDate(newStartDateForStudent),
        'originalServiceStartDate': Timestamp.fromDate(student.originalServiceStartDate), // Keep original start date
        'compensatoryDays': 0, // Reset compensatory days for the new period
        'currentCyclePaid': false, // New cycle is initially unpaid
        // Payment history is not cleared here, it's cumulative. Attendance log also cumulative.
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('New service period for ${student.name} will start automatically from ${DateFormat.yMMMd().format(newStartDateForStudent)}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting new auto period: $e'), backgroundColor: Colors.red));
    }
  }

  // New method for manually starting a service period
  void _startNewServicePeriodManually(Student student, DateTime manualStartDate) async {
    if (widget.userRole == UserRole.guest) return;
    if (student.isArchived) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot start new period for an archived student.'), backgroundColor: Colors.orange));
      return;
    }

    // Validate if manualStartDate is not in the past relative to today (or student's last effective end date if that's later)
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime earliestPossibleManualStart = student.effectiveMessEndDate.add(Duration(days: 1));
    if (earliestPossibleManualStart.isBefore(today)) {
      earliestPossibleManualStart = today;
    }

    if (manualStartDate.isBefore(earliestPossibleManualStart)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Manual start date cannot be before ${DateFormat.yMMMd().format(earliestPossibleManualStart)}.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }


    try {
      await widget.firestoreService.updateStudentPartial(student.id, {
        'messStartDate': Timestamp.fromDate(manualStartDate),
        // originalServiceStartDate should remain the very first date the student ever joined.
        // If this manual start is truly a "new" original start after a long break,
        // then originalServiceStartDate might also need to be `manualStartDate`.
        // For now, assuming originalServiceStartDate is preserved.
        'originalServiceStartDate': Timestamp.fromDate(student.originalServiceStartDate),
        'compensatoryDays': 0,
        'currentCyclePaid': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('New service period for ${student.name} manually set to start from ${DateFormat.yMMMd().format(manualStartDate)}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting new manual period: $e'), backgroundColor: Colors.red));
    }
  }


  void _showManualStartPeriodDialog(Student student) {
    if (widget.userRole == UserRole.guest || student.isArchived) return;

    _manualServiceStartDate = student.effectiveMessEndDate.add(Duration(days: 1));
    // Ensure the default manual start date is not before today
    if (_manualServiceStartDate!.isBefore(DateTime.now())) {
      _manualServiceStartDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    }


    showDialog(
      context: context,
      builder: (BuildContext dlgContext) {
        DateTime? tempPickedDate = _manualServiceStartDate; // Temporary variable for the dialog's date picker
        return StatefulBuilder( // Use StatefulBuilder for dialog's own state
            builder: (stfContext, stfSetState) {
              return AlertDialog(
                title: Text('Start Future Service Period'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select a future start date for ${student.name}.'),
                    SizedBox(height: 20),
                    Text('Current Effective End: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}'),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Text('New Start Date: ${DateFormat.yMMMd().format(tempPickedDate!)}')),
                        TextButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text('Change'),
                          onPressed: () async {
                            // Determine the first selectable date for the picker
                            DateTime firstPickerDate = student.effectiveMessEndDate.add(Duration(days: 1));
                            DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                            if (firstPickerDate.isBefore(today)) {
                              firstPickerDate = today; // Can't pick a date in the past
                            }

                            final DateTime? picked = await showDatePicker(
                              context: dlgContext,
                              initialDate: tempPickedDate!,
                              firstDate: firstPickerDate, // Start from day after current effective end or today
                              lastDate: DateTime.now().add(Duration(days: 365 * 2)), // Allow up to 2 years in future
                            );
                            if (picked != null && picked != tempPickedDate) {
                              stfSetState(() { // Update dialog's state
                                tempPickedDate = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dlgContext).pop()),
                  ElevatedButton(
                    child: Text('Set Start Date'),
                    onPressed: () {
                      if (tempPickedDate != null) {
                        _startNewServicePeriodManually(student, tempPickedDate!);
                        Navigator.of(dlgContext).pop();
                      }
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }


  void _showArchiveConfirmationDialog(Student student) {
    if (widget.userRole != UserRole.owner || student.isArchived) return;

    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: Text('Confirm Archive'),
            content: Text('Are you sure you want to archive ${student.name}?\n\nThis student will be moved to the archived list and will not appear in active operations. This action can be performed even if payments are not settled. Their record will be preserved.'),
            actions: <Widget>[
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
                  child: Text('Archive Student'),
                  onPressed: () async {
                    try {
                      await widget.firestoreService.setStudentArchiveStatus(student.id, true);
                      if (!mounted) return;
                      Navigator.of(ctx).pop(); // Close dialog
                      Navigator.of(context).pop(true); // Pop detail screen, indicate success to refresh previous list
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student.name} has been archived.')));
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.of(ctx).pop(); // Close dialog
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error archiving student: $e'), backgroundColor: Colors.red));
                    }
                  }),
            ],
          );
        });
  }

  void _showDeleteConfirmationDialog(Student student) {
    if (widget.userRole != UserRole.owner) return;

    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: Text('Confirm Delete'),
            content: Text('Are you sure you want to PERMANENTLY DELETE ${student.name} (${student.contactNumber})? This action cannot be undone and all historical data will be lost.\n\nConsider archiving if you want to retain records.'),
            actions: <Widget>[
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Delete Permanently'),
                  onPressed: () async {
                    try {
                      await widget.firestoreService.deleteStudent(student.id);
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student.name} has been permanently deleted.')));
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red));
                    }
                  }),
            ],
          );
        });
  }


  // lib/screens/student_detail_screen.dart
// ... (other parts of the file remain the same) ...
// Helper method to prepare attendance events (LOGIC UNCHANGED)
  void _prepareAttendanceEvents(Student student, Map<DateTime, List<AttendanceStatus>> eventsMap) {
    eventsMap.clear();
    for (var entry in student.attendanceLog) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (eventsMap[day] == null) {
        eventsMap[day] = [];
      }
      eventsMap[day]!.add(entry.status);
    }
  }

// Helper method to build markers (UI ENHANCED, LOGIC FOR WHICH MARKER TO SHOW UNCHANGED)
  List<Widget> _getAttendanceMarkersForDay(BuildContext context, DateTime day, Map<DateTime, List<AttendanceStatus>> eventsMap) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final statuses = eventsMap[normalizedDay];
    final theme = Theme.of(context); // Use theme for colors

    List<Widget> markers = [];

    // Present marker takes precedence
    if (statuses != null && statuses.contains(AttendanceStatus.present)) {
      markers.add(
        Positioned(
          right: 3, // Adjust position as needed
          bottom: 3, // Adjust position as needed
          child: Container(
            decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.85), // Use primary theme color
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: Offset(0,1)
                  )
                ]
            ),
            padding: EdgeInsets.all(2.0),
            child: Icon(Icons.check, color: Colors.white, size: 11), // Smaller icon
          ),
        ),
      );
    }
    // If not explicitly present, default to showing an absent marker for any day within service range.
    // The calendar itself will handle not showing days outside the student's service range if `firstDay` and `lastDay` are set appropriately.
    // So, if a day is rendered and not marked present, we mark it absent.
    else {
      markers.add(
        Positioned(
          right: 3,
          bottom: 3,
          child: Container(
            decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.8), // Use error theme color
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: Offset(0,1)
                  )
                ]
            ),
            padding: EdgeInsets.all(2.0),
            child: Icon(Icons.close, color: Colors.white, size: 11), // Smaller icon
          ),
        ),
      );
    }
    return markers;
  }

// Attendance Log Dialog (UI ENHANCED, CORE LOGIC UNCHANGED)
  void _showAttendanceLogDialog(Student student) {
    Map<DateTime, List<AttendanceStatus>> _dialogAttendanceEvents = {};
    _prepareAttendanceEvents(student, _dialogAttendanceEvents); // LOGIC UNCHANGED

    // Determine a sensible initial focused day
    DateTime _dialogFocusedDay = DateTime.now();
    if (student.attendanceLog.isNotEmpty) {
      // Try to focus on the month of the last logged attendance if it's recent
      DateTime lastLoggedDate = student.attendanceLog.last.date;
      if (lastLoggedDate.isAfter(DateTime.now().subtract(Duration(days: 180))) && lastLoggedDate.isBefore(DateTime.now().add(Duration(days:30)))) {
        _dialogFocusedDay = lastLoggedDate;
      }
    }
    // Clamp focused day to be within student's service if possible, or near today
    // Use student.originalServiceStartDate as the earliest possible focus if it's sensible
    DateTime earliestFocus = student.originalServiceStartDate;
    if (student.messStartDate.isAfter(earliestFocus)) { // If current cycle start is later, prefer that as a sensible start
      earliestFocus = student.messStartDate;
    }


    if (_dialogFocusedDay.isBefore(earliestFocus) && earliestFocus.isBefore(DateTime.now().add(Duration(days:30)))) {
      _dialogFocusedDay = earliestFocus;
    }
    if (_dialogFocusedDay.isAfter(DateTime.now().add(Duration(days:90)))){ // Don't focus too far in future by default
      _dialogFocusedDay = DateTime.now();
    }


    DateTime? _dialogSelectedDay = _dialogFocusedDay;
    CalendarFormat _dialogCalendarFormat = CalendarFormat.month;
    final theme = Theme.of(context); // Get theme context for styling

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: theme.cardColor,

                title: Text(
                  "Attendance: ${student.name.split(" ").first}",
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600
                  ),
                  textAlign: TextAlign.center,
                ),
                content: SizedBox( // <--- ADDED SizedBox to constrain height
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.50, // Adjust height as needed (e.g., 55% of screen height)
                  child: TableCalendar<AttendanceStatus>(
                    // --- Date Range ---
                    firstDay: student.originalServiceStartDate.subtract(Duration(days:30)),
                    lastDay: student.effectiveMessEndDate.add(Duration(days: 30)).isAfter(DateTime.now().add(Duration(days:365*2))) ? student.effectiveMessEndDate.add(Duration(days:30)) : DateTime.now().add(Duration(days: 365 * 2)),

                    // --- Core Calendar Logic (UNCHANGED) ---
                    focusedDay: _dialogFocusedDay,
                    calendarFormat: _dialogCalendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_dialogSelectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      DateTime firstValidDay = student.originalServiceStartDate.subtract(Duration(days:30));
                      DateTime lastValidDay = student.effectiveMessEndDate.add(Duration(days: 30)).isAfter(DateTime.now().add(Duration(days:365*2))) ? student.effectiveMessEndDate.add(Duration(days:30)) : DateTime.now().add(Duration(days: 365 * 2));

                      if (!selectedDay.isBefore(firstValidDay) && !selectedDay.isAfter(lastValidDay)) {
                        setStateDialog(() {
                          _dialogSelectedDay = selectedDay;
                          _dialogFocusedDay = focusedDay;
                        });
                      }
                    },
                    onFormatChanged: (format) {
                      if (_dialogCalendarFormat != format) {
                        setStateDialog(() { _dialogCalendarFormat = format; });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      DateTime firstValidDay = student.originalServiceStartDate.subtract(Duration(days:30));
                      DateTime lastValidDay = student.effectiveMessEndDate.add(Duration(days: 30)).isAfter(DateTime.now().add(Duration(days:365*2))) ? student.effectiveMessEndDate.add(Duration(days:30)) : DateTime.now().add(Duration(days: 365 * 2));

                      DateTime newFocusedDay = focusedDay;
                      if (focusedDay.isBefore(firstValidDay)){
                        newFocusedDay = firstValidDay;
                      } else if (focusedDay.isAfter(lastValidDay)){
                        newFocusedDay = lastValidDay;
                      }

                      if (isSameDay(_dialogFocusedDay, newFocusedDay)) return;

                      _dialogFocusedDay = newFocusedDay;
                      setStateDialog((){});
                    },

                    // --- UI Styling ---
                    headerStyle: HeaderStyle(
                      titleTextStyle: theme.textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 18
                      ),
                      titleTextFormatter: (date, locale) => DateFormat.yMMMM(locale).format(date),
                      formatButtonTextStyle: TextStyle(color: theme.colorScheme.onSecondary, fontSize: 12.0),
                      formatButtonDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: theme.colorScheme.secondary)
                      ),
                      formatButtonPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      formatButtonShowsNext: false,
                      leftChevronIcon: Icon(Icons.chevron_left, color: theme.colorScheme.primary, size: 28),
                      rightChevronIcon: Icon(Icons.chevron_right, color: theme.colorScheme.primary, size: 28),
                      headerPadding: EdgeInsets.symmetric(vertical: 8.0),
                      decoration: BoxDecoration(
                        // color: theme.primaryColor.withOpacity(0.05),
                      ),
                      titleCentered: true,
                    ),
                    daysOfWeekHeight: 24.0,
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: theme.textTheme.bodySmall!.copyWith(
                          color: theme.textTheme.bodySmall!.color!.withOpacity(0.8),
                          fontWeight: FontWeight.w600
                      ),
                      weekendStyle: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.error.withOpacity(0.7),
                          fontWeight: FontWeight.w600
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      defaultTextStyle: theme.textTheme.bodyMedium!.copyWith(fontSize: 14.5),
                      weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.error, fontSize: 14.5),
                      holidayTextStyle: theme.textTheme.bodyMedium!.copyWith(color: Colors.blue[700], fontSize: 14.5),

                      todayTextStyle: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSecondary, fontWeight: FontWeight.bold, fontSize: 14.5),
                      todayDecoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 14.5),
                      selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0,1))
                          ]
                      ),
                      cellMargin: EdgeInsets.all(5.0),
                      cellAlignment: Alignment.center,
                      markersAlignment: Alignment.bottomCenter,
                      markerDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle
                      ),
                      markerSize: 5.0,
                      markersMaxCount: 1,
                      markerMargin: const EdgeInsets.only(top: 0.5),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (builderContext, date, events) {
                        if (date.isBefore(student.originalServiceStartDate) || date.isAfter(student.effectiveMessEndDate)) {
                          return SizedBox.shrink();
                        }
                        final markers = _getAttendanceMarkersForDay(builderContext, date, _dialogAttendanceEvents);
                        if (markers.isNotEmpty) {
                          return Stack(children: markers);
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: Text("Close", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontSize: 15)),
                      onPressed: () => Navigator.of(dialogContext).pop()
                  )
                ],
              );
            }
        );
      },
    );
  }

// ... (rest of the StudentDetailScreen.dart file remains the same) ...




  Widget _buildDetailCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
              flex: 2,
              child: Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[700]))
          ),
          SizedBox(width: 10),
          Flexible(
              flex: 3,
              child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: isEmphasized ? FontWeight.bold : FontWeight.normal,
                      color: isEmphasized ? Colors.teal[700] : Colors.black87
                  )
              )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.userRole == UserRole.owner;

    return StreamBuilder<AppSettings>(
      stream: widget.firestoreService.getAppSettingsStream(),
      builder: (context, appSettingsSnapshot) {
        if (appSettingsSnapshot.connectionState == ConnectionState.waiting && !appSettingsSnapshot.hasData) {
          return Scaffold(appBar: AppBar(title: Text("Loading Settings...")), body: Center(child: CircularProgressIndicator()));
        }
        if (appSettingsSnapshot.hasError) {
          return Scaffold(appBar: AppBar(title: Text("Error")), body: Center(child: Text('Error loading app settings: ${appSettingsSnapshot.error}')));
        }

        final double standardMonthlyFee = appSettingsSnapshot.data?.standardMonthlyFee ?? 2000.0;

        return StreamBuilder<Student?>(
          stream: widget.firestoreService.getStudentStream(widget.studentId),
          builder: (context, studentSnapshot) {
            if (studentSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(appBar: AppBar(title: Text("Loading Student...")), body: Center(child: CircularProgressIndicator()));
            }
            if (studentSnapshot.hasError) {
              return Scaffold(appBar: AppBar(title: Text("Error")), body: Center(child: Text('Error: ${studentSnapshot.error}')));
            }
            if (!studentSnapshot.hasData || studentSnapshot.data == null) {
              return Scaffold(appBar: AppBar(title: Text("Not Found")), body: Center(child: Text('Student not found.')));
            }

            final student = studentSnapshot.data!;
            final List<MonthlyDueItem> billingPeriods = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(student, standardMonthlyFee, DateTime.now());
            final double totalRemainingAmount = billingPeriods.fold(0.0, (sum, item) => sum + item.remainingForPeriod);

            return WillPopScope(
              onWillPop: () async {
                Navigator.pop(context, true); // Indicate a potential change that might require list refresh
                return true;
              },
              child: Scaffold(
                appBar: AppBar(
                  title: Hero(
                      tag: 'student_name_${student.id}',
                      child: Material(
                          type: MaterialType.transparency,
                          child: Text(student.name + (student.isArchived ? " (Archived)" : ""))
                      )
                  ),
                  actions: [
                    if (isOwner && !student.isArchived)
                      IconButton(
                        icon: Icon(Icons.archive_outlined, color: Colors.orange[700]),
                        tooltip: 'Archive Student',
                        onPressed: () => _showArchiveConfirmationDialog(student),
                      ),
                    if (isOwner)
                      IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent[100]),
                          tooltip: 'Delete Student Permanently',
                          onPressed: () => _showDeleteConfirmationDialog(student)
                      ),
                  ],
                ),
                body: Opacity(
                  opacity: student.isArchived ? 0.7 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView(
                      children: <Widget>[
                        if (student.isArchived)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Card(
                              color: Colors.grey[300],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  "This student's record is ARCHIVED. Data is view-only. No further actions like payments or new service periods can be applied.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                                ),
                              ),
                            ),
                          ),
                        _buildDetailCard(context, title: 'Student Information', icon: Icons.person_pin_circle_outlined, children: [
                          _buildInfoRow('Name:', student.name),
                          _buildInfoRow('Contact (ID):', student.contactNumber),
                          _buildInfoRow('Status:', student.isArchived ? 'Archived' : 'Active', isEmphasized: student.isArchived),
                        ]),
                        SizedBox(height: 16),
                        _buildDetailCard(context, title: 'Mess Service Information', icon: Icons.calendar_today_outlined, children: [
                          _buildInfoRow('Original Service Start:', DateFormat.yMMMd().format(student.originalServiceStartDate)),
                          _buildInfoRow('Current Cycle Start:', DateFormat.yMMMd().format(student.messStartDate)),
                          if (isOwner) _buildInfoRow('Compensatory Days:', '${student.compensatoryDays} days'),
                          _buildInfoRow('Effective Service End Date:', DateFormat.yMMMd().format(student.effectiveMessEndDate), isEmphasized: true),
                        ]),
                        SizedBox(height: 16),

                        if (isOwner)
                          _buildDetailCard(context, title: 'Payment Overview', icon: Icons.monetization_on_outlined, children: [
                            _buildInfoRow('Standard Monthly Fee:', '₹${standardMonthlyFee.toStringAsFixed(2)}'),
                            _buildInfoRow('Total Remaining Dues (All Periods):', '₹${totalRemainingAmount.toStringAsFixed(2)}', isEmphasized: totalRemainingAmount > 0),
                            SizedBox(height: 10),
                            if (!student.isArchived)
                              ElevatedButton.icon(
                                  icon: Icon(Icons.payment),
                                  label: Text('Record New Payment'),
                                  onPressed: () => _recordPaymentDialog(student, billingPeriods, standardMonthlyFee),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
                            SizedBox(height: 10),
                            Text("Billing Period Breakdown:", style: Theme.of(context).textTheme.titleMedium),
                            if (billingPeriods.isEmpty) Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text("No billing periods generated yet or student not active.", style: TextStyle(fontStyle: FontStyle.italic)),
                            ) else
                              SizedBox(
                                height: 120,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: billingPeriods.map((dueItem) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${dueItem.monthYearDisplay}:", style: TextStyle(fontWeight: FontWeight.w500)),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                            child: Text(
                                              "(Period: ${DateFormat.yMMMd().format(dueItem.periodStartDate)} - ${DateFormat.yMMMd().format(dueItem.periodEndDate)})",
                                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                                            child: Text(
                                              "Paid: ₹${dueItem.amountPaidForPeriod.toStringAsFixed(0)}, Remaining: ₹${dueItem.remainingForPeriod.toStringAsFixed(0)} (${dueItem.status})",
                                              style: TextStyle(fontSize: 13, color: dueItem.status == "Paid" ? Colors.green : (dueItem.status == "Partially Paid" ? Colors.orange.shade700 : Colors.red.shade700)),
                                            ),
                                          ),
                                          if (billingPeriods.last != dueItem) Divider(height: 1, thickness: 0.5),
                                        ],
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ),
                            SizedBox(height: 10),
                            TextButton(onPressed: () {
                              if (student.paymentHistory.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No payment history for ${student.name}.'))); return;
                              }
                              showDialog(context: context, builder: (ctx) => AlertDialog(
                                  title: Text("Detailed Payment Entries for ${student.name}"),
                                  content: Container(
                                      width: double.maxFinite,
                                      child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: student.paymentHistory.length,
                                          itemBuilder: (iCtx, idx) {
                                            final entry = student.paymentHistory.reversed.toList()[idx]; // Show newest first
                                            return Card(
                                                margin: EdgeInsets.symmetric(vertical: 4),
                                                child: ListTile(
                                                  title: Text("Paid on: ${DateFormat.yMMMd().format(entry.paymentDate)} - Amount: ₹${entry.amountPaid.toStringAsFixed(2)}"),
                                                  subtitle: Text("For Period Starting: ${DateFormat.yMMMd().format(entry.cycleStartDate)}"),
                                                  leading: Icon(entry.paid ? Icons.check_circle : Icons.history_toggle_off, color: entry.paid ? Colors.green : Colors.blueGrey),
                                                  isThreeLine: false,
                                                ));
                                          })),
                                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text("Close"))]));
                            }, child: Text('View All Payment Entries')),
                          ]),
                        if (isOwner) SizedBox(height: 16),

                        _buildDetailCard(context, title: 'Attendance', icon: Icons.fact_check_outlined, children: [
                          TextButton(
                              onPressed: () => _showAttendanceLogDialog(student),
                              child: Text('View Attendance Calendar')
                          ),
                        ]),
                        SizedBox(height: 16),

                        if (isOwner && !student.isArchived)
                          _buildDetailCard(context, title: 'Compensatory Days', icon: Icons.control_point_duplicate_outlined, children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.add_circle_outline),
                              label: Flexible(child: Text('Add Compensatory Days', overflow: TextOverflow.ellipsis)),
                              onPressed: () => _addCompensatoryDaysDialog(student),
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, 36),
                              ),
                            ),
                            if (student.compensatoryDays > 0) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Current total: ${student.compensatoryDays} days added.', style: TextStyle(fontStyle: FontStyle.italic)))
                          ]),
                        if (isOwner && !student.isArchived) SizedBox(height: 24),

                        // --- Updated Start New Service Period Section ---
                        if (isOwner && !student.isArchived)
                          _buildDetailCard(context, title: 'Manage Service Period', icon: Icons.event_repeat_outlined, children: [
                            Text(
                              "Use these options to start the next service cycle for ${student.name}.",
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                            SizedBox(height: 15),
                            ElevatedButton.icon(
                              icon: Icon(Icons.play_circle_outline),
                              label: Text('Start Next Period (Auto)'),
                              onPressed: () => _startNextServicePeriodAuto(student),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 40),
                                  padding: EdgeInsets.symmetric(vertical: 10)
                              ),
                            ),
                            SizedBox(height: 10),
                            ElevatedButton.icon(
                              icon: Icon(Icons.date_range_outlined),
                              label: Text('Start Future Period (Manual)'),
                              onPressed: () => _showManualStartPeriodDialog(student),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent[100],
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 40),
                                  padding: EdgeInsets.symmetric(vertical: 10)
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                "Auto: Starts immediately after the current 'Effective Service End Date' (adjusts to current month's start if needed).\nManual: Choose a specific future date to begin the new service period.",
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            )
                          ]),
                        if (isOwner && !student.isArchived) SizedBox(height: 20),
                        // --- End of Updated Section ---

                        SizedBox(height: 20), // General spacing at the bottom
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
