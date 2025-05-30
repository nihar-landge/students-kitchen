// lib/screens/student_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';
import '../services/firestore_service.dart';
import '../utils/string_extensions.dart';

// Helper class for displaying monthly dues
class MonthlyDueItem {
  final String monthYearDisplay;
  final DateTime monthStartDate;
  final double feeDueForMonth;
  double amountPaidForMonth;
  String status;

  MonthlyDueItem({
    required this.monthYearDisplay,
    required this.monthStartDate,
    required this.feeDueForMonth,
    this.amountPaidForMonth = 0.0,
  }) : status = (amountPaidForMonth >= feeDueForMonth)
      ? "Paid"
      : (amountPaidForMonth > 0 ? "Partially Paid" : "Unpaid");

  double get remainingForMonth => feeDueForMonth - amountPaidForMonth;

  void updateStatus() {
    status = (amountPaidForMonth >= feeDueForMonth)
        ? "Paid"
        : (amountPaidForMonth > 0 ? "Partially Paid" : "Unpaid");
  }
}


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
  DateTime? _paymentForMonth;

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

  List<MonthlyDueItem> _calculateMonthlyDuesWithPaymentAllocation(
      Student student, double standardMonthlyFee, DateTime upToDate) {
    List<MonthlyDueItem> monthlyDues = [];
    if (student.messStartDate.isAfter(upToDate) &&
        !(student.messStartDate.year == upToDate.year && student.messStartDate.month == upToDate.month)) {
      // If mess start is in a future month compared to 'upToDate', no dues yet up to 'upToDate'.
      // However, we typically want to show the current month if student is active.
      // Let's ensure 'upToDate' covers at least the start of the current service period.
    }


    DateTime monthIterator = DateTime(student.messStartDate.year, student.messStartDate.month, 1);
    // Determine the last month to generate dues for.
    // It should be the current month, or the student's effective end date's month if that's past & relevant.
    DateTime today = DateTime.now();
    DateTime lastMonthToConsider = DateTime(today.year, today.month, 1);
    if (student.effectiveMessEndDate.isBefore(today) && student.effectiveMessEndDate.isAfter(student.messStartDate)) {
      lastMonthToConsider = DateTime(student.effectiveMessEndDate.year, student.effectiveMessEndDate.month, 1);
    }
    // If messStartDate is in the future compared to today, we still might want to show the first month's due.
    if (monthIterator.isAfter(lastMonthToConsider) &&
        (monthIterator.year == student.messStartDate.year && monthIterator.month == student.messStartDate.month) ) {
      lastMonthToConsider = monthIterator;
    }


    while (monthIterator.isBefore(lastMonthToConsider) || monthIterator.isAtSameMomentAs(lastMonthToConsider)) {
      DateTime monthEndForIterator = DateTime(monthIterator.year, monthIterator.month + 1, 0);
      // A student is active in a month if their service period overlaps with that month.
      bool isActiveThisMonth = !(student.messStartDate.isAfter(monthEndForIterator) || student.effectiveMessEndDate.isBefore(monthIterator));

      if (isActiveThisMonth) {
        monthlyDues.add(MonthlyDueItem(
          monthYearDisplay: DateFormat('MMMM yyyy').format(monthIterator), // Corrected DateFormat
          monthStartDate: monthIterator,
          feeDueForMonth: standardMonthlyFee,
        ));
      }
      // Move to the first day of the next month
      if (monthIterator.month == 12) {
        monthIterator = DateTime(monthIterator.year + 1, 1, 1);
      } else {
        monthIterator = DateTime(monthIterator.year, monthIterator.month + 1, 1);
      }
    }

    // Allocate payments strictly to the month they were recorded for
    for (var payment in student.paymentHistory) {
      if (!payment.paid) continue; // Skip entries that are not actual payments (e.g., if 'paid' was false)

      DateTime paymentForMonthStart = DateTime(payment.cycleStartDate.year, payment.cycleStartDate.month, 1);

      for (var dueItem in monthlyDues) {
        if (dueItem.monthStartDate.isAtSameMomentAs(paymentForMonthStart)) {
          dueItem.amountPaidForMonth += payment.amountPaid;
          dueItem.updateStatus();
          break;
        }
      }
    }
    return monthlyDues;
  }

  void _recordPaymentDialog(Student student, List<MonthlyDueItem> monthlyDues) {
    // ... (Dialog content unchanged, logic for saving payment might need to ensure
    // PaymentHistoryEntry.cycleStartDate and cycleEndDate correctly reflect the month)
    // The current _recordPaymentDialog seems to set cycleStartDate to _paymentForMonth,
    // and cycleEndDate to the end of that _paymentForMonth. This is correct for the new logic.
    _paymentAmountController.clear();
    _selectedPaymentDate = DateTime.now();
    _paymentForMonth = null;

    MonthlyDueItem? suggestedMonth = monthlyDues.firstWhere(
            (due) => due.status != "Paid",
        orElse: () {
          // If all listed dues are paid, or no dues yet, suggest current month
          DateTime now = DateTime.now();
          DateTime currentMonthStart = DateTime(now.year, now.month, 1);
          // Check if current month is already in the list, if not, create a temporary item for suggestion
          var currentMonthDueItem = monthlyDues.firstWhere(
                  (d) => d.monthStartDate.isAtSameMomentAs(currentMonthStart),
              orElse: () => MonthlyDueItem(
                  monthYearDisplay: DateFormat("MMMM yyyy").format(currentMonthStart),
                  monthStartDate: currentMonthStart,
                  feeDueForMonth: 0 // This is just for display in dropdown, actual fee comes from settings
              )
          );
          return currentMonthDueItem;
        }
    );
    _paymentForMonth = suggestedMonth.monthStartDate;


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
                SizedBox(height: 16),
                // Create a list of months for the dropdown, including potentially the current month if not in dues.
                Builder(builder: (context) {
                  List<MonthlyDueItem> dropdownMonths = List.from(monthlyDues);
                  DateTime now = DateTime.now();
                  DateTime currentMonthStartForDropdown = DateTime(now.year, now.month, 1);
                  if (!dropdownMonths.any((due) => due.monthStartDate.isAtSameMomentAs(currentMonthStartForDropdown))) {
                    dropdownMonths.add(MonthlyDueItem(
                        monthYearDisplay: DateFormat("MMMM yyyy").format(currentMonthStartForDropdown),
                        monthStartDate: currentMonthStartForDropdown,
                        feeDueForMonth: 0 // Placeholder fee for display
                    ));
                    dropdownMonths.sort((a,b) => a.monthStartDate.compareTo(b.monthStartDate));
                  }

                  if (dropdownMonths.isEmpty && _paymentForMonth == null) {
                    // If student has no dues and current month is not added, default _paymentForMonth
                    _paymentForMonth = currentMonthStartForDropdown;
                  }


                  return DropdownButtonFormField<DateTime>(
                    decoration: InputDecoration(labelText: "Payment For Month", border: OutlineInputBorder()),
                    value: _paymentForMonth,
                    items: dropdownMonths
                        .map((dueItem) => DropdownMenuItem<DateTime>(
                      value: dueItem.monthStartDate,
                      child: Text(dueItem.monthYearDisplay + (dueItem.feeDueForMonth > 0 && dueItem.remainingForMonth > 0 ? " (Due: ₹${dueItem.remainingForMonth.toStringAsFixed(0)})" : (dueItem.feeDueForMonth > 0 ? " (Cleared)" : ""))),
                    ))
                        .toList(),
                    onChanged: (DateTime? newValue) {
                      stfSetState(() {
                        _paymentForMonth = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Please select a month' : null,
                  );
                }),
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
                    if (_paymentForMonth == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select the month this payment is for.'), backgroundColor: Colors.red));
                      return;
                    }

                    List<PaymentHistoryEntry> updatedHistory = List.from(student.paymentHistory);
                    updatedHistory.add(PaymentHistoryEntry(
                        paymentDate: _selectedPaymentDate,
                        cycleStartDate: _paymentForMonth!,
                        cycleEndDate: DateTime(_paymentForMonth!.year, _paymentForMonth!.month + 1, 0),
                        paid: true,
                        amountPaid: amount
                    ));

                    bool updatedCurrentCyclePaidFlag = student.currentCyclePaid;
                    final AppSettings appSettings = await widget.firestoreService.getAppSettingsStream().first;
                    List<MonthlyDueItem> duesAfterPayment = _calculateMonthlyDuesWithPaymentAllocation(
                        Student(
                            id: student.id, name: student.name,
                            messStartDate: student.messStartDate,
                            compensatoryDays: student.compensatoryDays,
                            currentCyclePaid: student.currentCyclePaid,
                            attendanceLog: student.attendanceLog,
                            paymentHistory: updatedHistory
                        ),
                        appSettings.standardMonthlyFee,
                        DateTime.now()
                    );

                    DateTime currentActiveMonthStart = DateTime(student.messStartDate.year, student.messStartDate.month, 1);
                    if (DateTime.now().isAfter(currentActiveMonthStart) && (DateTime.now().year > currentActiveMonthStart.year || DateTime.now().month > currentActiveMonthStart.month) ) {
                      currentActiveMonthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
                    }


                    MonthlyDueItem? currentMonthDueInfo = duesAfterPayment.firstWhere(
                            (due) => due.monthStartDate.isAtSameMomentAs(currentActiveMonthStart),
                        orElse: () => MonthlyDueItem(monthYearDisplay: "N/A", monthStartDate: DateTime(0), feeDueForMonth: 0)
                    );
                    if(currentMonthDueInfo.monthStartDate.year != 0){
                      updatedCurrentCyclePaidFlag = currentMonthDueInfo.status == "Paid";
                    }


                    try {
                      await widget.firestoreService.updateStudentPartial(student.id, {
                        'currentCyclePaid': updatedCurrentCyclePaidFlag,
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

  void _handlePaymentStatusChange(Student student, List<MonthlyDueItem> monthlyDues) {
    _recordPaymentDialog(student, monthlyDues);
  }

  void _addCompensatoryDaysDialog(Student student) { /* ... same as before ... */
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

  void _startNewServicePeriod(Student student) async { // Renamed from _renewMessCycle
    DateTime newStartDateForStudent = student.effectiveMessEndDate.add(Duration(days: 1));
    DateTime today = DateTime.now();
    DateTime firstOfThisMonth = DateTime(today.year, today.month, 1);
    DateTime firstOfNextMonth = DateTime(today.year, today.month +1, 1);

    // If the effective end date is in the past, decide the new start.
    // Usually, it would be the first of the current month if ending in a past month,
    // or first of next month if ending in current month but already passed.
    // Or simply the day after effectiveMessEndDate.
    // Let's simplify: if effectiveMessEndDate is before today, start new cycle from firstOfThisMonth or firstOfNextMonth
    // to align with monthly billing. If it's in future, newStartDateForStudent is fine.

    if (student.effectiveMessEndDate.isBefore(firstOfThisMonth)) {
      newStartDateForStudent = firstOfThisMonth; // Ended in a past month, start new from 1st of current
    } else if (student.effectiveMessEndDate.isBefore(today)) { // Ended this month, but before today
      newStartDateForStudent = firstOfNextMonth; // Start from 1st of next month
    } // Else, if effectiveEndDate is today or in future, newStartDateForStudent (day after) is fine.


    try {
      await widget.firestoreService.updateStudentPartial(student.id, {
        'messStartDate': Timestamp.fromDate(newStartDateForStudent),
        'compensatoryDays': 0,
        'currentCyclePaid': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('New service period for ${student.name} will start from ${DateFormat.yMMMd().format(newStartDateForStudent)}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting new service period: $e'), backgroundColor: Colors.red));
    }
  }

  void _showDeleteConfirmationDialog(Student student) { /* ... same as before ... */
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

  void _prepareAttendanceEvents(Student student, Map<DateTime, List<AttendanceStatus>> eventsMap) {
    // ... (same as before)
    eventsMap.clear();
    for (var entry in student.attendanceLog) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (eventsMap[day] == null) {
        eventsMap[day] = [];
      }
      eventsMap[day]!.add(entry.status);
    }
  }

  List<Widget> _getAttendanceMarkersForDay(DateTime day, Map<DateTime, List<AttendanceStatus>> eventsMap) {
    // ... (same as before)
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final statuses = eventsMap[normalizedDay];
    if (statuses == null || statuses.isEmpty) return [];
    if (statuses.contains(AttendanceStatus.present)) {
      return [ Positioned( right: 1, bottom: 1, child: Icon(Icons.check_circle, color: Colors.green, size: 16)) ];
    }
    if (statuses.every((status) => status == AttendanceStatus.absent)) {
      return [ Positioned( right: 1, bottom: 1, child: Icon(Icons.cancel, color: Colors.red, size: 16)) ];
    }
    return [];
  }

  void _showAttendanceLogDialog(Student student) {
    // ... (same as before)
    Map<DateTime, List<AttendanceStatus>> _dialogAttendanceEvents = {};
    _prepareAttendanceEvents(student, _dialogAttendanceEvents);
    DateTime _dialogFocusedDay = student.attendanceLog.isNotEmpty
        ? student.attendanceLog.last.date
        : DateTime.now();
    DateTime? _dialogSelectedDay = _dialogFocusedDay;
    CalendarFormat _dialogCalendarFormat = CalendarFormat.month;


    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return AlertDialog(
                title: Text("Attendance Log for ${student.name}"),
                content: Container(
                  width: double.maxFinite,
                  child: TableCalendar<AttendanceStatus>(
                    firstDay: student.messStartDate.subtract(Duration(days: 90)),
                    lastDay: DateTime.now().add(Duration(days: 365)),
                    focusedDay: _dialogFocusedDay,
                    calendarFormat: _dialogCalendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_dialogSelectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setStateDialog(() {
                        _dialogSelectedDay = selectedDay;
                        _dialogFocusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      if (_dialogCalendarFormat != format) {
                        setStateDialog(() { _dialogCalendarFormat = format; });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      setStateDialog(() { _dialogFocusedDay = focusedDay;});
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        final markers = _getAttendanceMarkersForDay(date, _dialogAttendanceEvents);
                        if (markers.isNotEmpty) {
                          return Stack(children: markers);
                        }
                        return null;
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(color: Colors.amber.shade200, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                    ),
                    headerStyle: HeaderStyle(formatButtonVisible: true, titleCentered: true),
                  ),
                ),
                actions: <Widget>[ TextButton(child: Text("Close"), onPressed: () => Navigator.of(context).pop()) ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSettings>(
      stream: widget.firestoreService.getAppSettingsStream(),
      builder: (context, appSettingsSnapshot) {
        // ... (loading/error for app settings)
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
            // ... (loading/error for student)
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
            final List<MonthlyDueItem> monthlyDues = _calculateMonthlyDuesWithPaymentAllocation(student, standardMonthlyFee, DateTime.now());
            final double totalRemainingAmount = monthlyDues.fold(0.0, (sum, item) => sum + item.remainingForMonth);

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
                      _buildDetailCard(context, title: 'Mess Service Information', icon: Icons.calendar_today_outlined, children: [
                        _buildInfoRow('Service Start Date:', DateFormat.yMMMd().format(student.messStartDate)),
                        _buildInfoRow('Compensatory Days:', '${student.compensatoryDays} days'),
                        _buildInfoRow('Effective Service End Date:', DateFormat.yMMMd().format(student.effectiveMessEndDate), isEmphasized: true),
                      ]),
                      SizedBox(height: 16),
                      _buildDetailCard(context, title: 'Payment Overview', icon: Icons.monetization_on_outlined, children: [
                        _buildInfoRow('Standard Monthly Fee:', '₹${standardMonthlyFee.toStringAsFixed(2)}'),
                        _buildInfoRow('Total Remaining Dues:', '₹${totalRemainingAmount.toStringAsFixed(2)}', isEmphasized: totalRemainingAmount > 0),
                        SizedBox(height: 10),
                        ElevatedButton.icon(
                            icon: Icon(Icons.payment),
                            label: Text('Record New Payment'),
                            onPressed: () => _handlePaymentStatusChange(student, monthlyDues),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
                        SizedBox(height: 10),
                        Text("Monthly Breakdown:", style: Theme.of(context).textTheme.titleMedium),
                        if (monthlyDues.isEmpty) Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("No billing periods generated yet or student not active.", style: TextStyle(fontStyle: FontStyle.italic)),
                        ) else
                          ...monthlyDues.map((dueItem) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${dueItem.monthYearDisplay}: ", style: TextStyle(fontWeight: FontWeight.w500)),
                                Flexible(
                                  child: Text(
                                    "Due: ₹${dueItem.feeDueForMonth.toStringAsFixed(0)}, Paid: ₹${dueItem.amountPaidForMonth.toStringAsFixed(0)}, Rem: ₹${dueItem.remainingForMonth.toStringAsFixed(0)} (${dueItem.status})",
                                    style: TextStyle(color: dueItem.status == "Paid" ? Colors.green : (dueItem.status == "Partially Paid" ? Colors.orange.shade700 : Colors.red.shade700)),
                                    textAlign: TextAlign.end,
                                  ),
                                )
                              ],
                            ),
                          )).toList(),
                        SizedBox(height: 10),
                        TextButton(onPressed: () {
                          if (student.paymentHistory.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No payment history for ${student.name}.'))); return;
                          }
                          showDialog(context: context, builder: (ctx) => AlertDialog(
                              title: Text("Detailed Payment Entries for ${student.name}"),
                              content: Container(width: double.maxFinite, child: ListView.builder(
                                  shrinkWrap: true, itemCount: student.paymentHistory.length,
                                  itemBuilder: (iCtx, idx) {
                                    final entry = student.paymentHistory.reversed.toList()[idx];
                                    return Card(margin: EdgeInsets.symmetric(vertical: 4), child: ListTile(
                                      title: Text("Paid on: ${DateFormat.yMMMd().format(entry.paymentDate)} - Amount: ₹${entry.amountPaid.toStringAsFixed(2)}"),
                                      subtitle: Text("For Month Starting: ${DateFormat.yMMMd().format(entry.cycleStartDate)}"),
                                      leading: Icon(entry.paid ? Icons.check_circle : Icons.history_toggle_off, color: entry.paid ? Colors.green : Colors.blueGrey),
                                      isThreeLine: false,
                                    ));
                                  })),
                              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text("Close"))]));
                        }, child: Text('View All Payment Entries')),
                      ]),
                      SizedBox(height: 16),
                      _buildDetailCard(context, title: 'Attendance', icon: Icons.fact_check_outlined, children: [
                        TextButton(
                            onPressed: () => _showAttendanceLogDialog(student),
                            child: Text('View Attendance Calendar')
                        ),
                      ]),
                      SizedBox(height: 16),
                      _buildDetailCard(context, title: 'Manage Compensatory Days', icon: Icons.control_point_duplicate_outlined, children: [
                        ElevatedButton.icon(icon: Icon(Icons.add_circle_outline), label: Text('Add Compensatory Days'), onPressed: () => _addCompensatoryDaysDialog(student)),
                        if (student.compensatoryDays > 0) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Current total: ${student.compensatoryDays} days added.', style: TextStyle(fontStyle: FontStyle.italic)))
                      ]),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                          icon: Icon(Icons.event_repeat),
                          label: Text('Start New Service Period'), // Updated Label
                          onPressed: () => _startNewServicePeriod(student), // Updated method name & parameters
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12))),
                    ],
                  ),
                ),
              ),
            );
          },
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
          Flexible(child: Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[700]))),
          SizedBox(width: 10),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 15, fontWeight: isEmphasized ? FontWeight.bold : FontWeight.normal, color: isEmphasized ? Colors.teal[700] : Colors.black87))),
        ],
      ),
    );
  }
}
