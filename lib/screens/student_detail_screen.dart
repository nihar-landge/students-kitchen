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

    if (selectablePeriods.isEmpty && student.originalServiceStartDate.isAfter(DateTime.now().subtract(Duration(days:1)))) {
      DateTime firstPeriodStart = student.originalServiceStartDate;
      String displaySuffix = (firstPeriodStart.day != 1) ? " (from ${DateFormat.d().format(firstPeriodStart)})" : "";
      DateTime firstPeriodEnd = DateTime(firstPeriodStart.year, firstPeriodStart.month + 1, 0);
      if (firstPeriodEnd.isAfter(student.effectiveMessEndDate)) {
        firstPeriodEnd = student.effectiveMessEndDate;
      }
      selectablePeriods.add(MonthlyDueItem(
          monthYearDisplay: DateFormat('MMMM yy').format(firstPeriodStart) + displaySuffix,
          periodStartDate: firstPeriodStart,
          periodEndDate: firstPeriodEnd,
          feeDueForPeriod: standardMonthlyFee,
          amountPaidForPeriod: 0.0
      ));
    }
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
          final List<MonthlyDueItem> periodsForDropdown = selectablePeriods.where((due) => due.remainingForPeriod > 0).toList();

          if (_paymentForPeriodStart != null && !periodsForDropdown.any((p) => p.periodStartDate.isAtSameMomentAs(_paymentForPeriodStart!))) {
            _paymentForPeriodStart = periodsForDropdown.isNotEmpty ? periodsForDropdown.first.periodStartDate : null;
          } else if (_paymentForPeriodStart == null && periodsForDropdown.isNotEmpty) {
            _paymentForPeriodStart = periodsForDropdown.first.periodStartDate;
          }

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
                      icon: Icon(Icons.calendar_today),
                      label: Text('Change'),
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
                if (periodsForDropdown.isNotEmpty)
                  DropdownButtonFormField<DateTime>(
                    decoration: InputDecoration(labelText: "Payment For Period Starting", border: OutlineInputBorder()),
                    value: _paymentForPeriodStart,
                    items: periodsForDropdown
                        .map((dueItem) => DropdownMenuItem<DateTime>(
                      value: dueItem.periodStartDate,
                      child: Text(dueItem.monthYearDisplay + " (Due: ₹${dueItem.remainingForPeriod.toStringAsFixed(0)})"),
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
                    child: Text("No periods with outstanding dues available for selection.", style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
              ]),
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No payment period selected or available.'), backgroundColor: Colors.red));
                      return;
                    }

                    List<PaymentHistoryEntry> updatedHistory = List.from(student.paymentHistory);
                    MonthlyDueItem paidForPeriodDetails = selectablePeriods.firstWhere(
                            (p) => p.periodStartDate.isAtSameMomentAs(_paymentForPeriodStart!),
                        orElse: () => MonthlyDueItem(
                            monthYearDisplay: "Error: Period Not Found",
                            periodStartDate: _paymentForPeriodStart!,
                            periodEndDate: DateTime(_paymentForPeriodStart!.year, _paymentForPeriodStart!.month+1,0),
                            feeDueForPeriod: 0
                        )
                    );

                    updatedHistory.add(PaymentHistoryEntry(
                        paymentDate: _selectedPaymentDate,
                        cycleStartDate: paidForPeriodDetails.periodStartDate,
                        cycleEndDate: paidForPeriodDetails.periodEndDate,
                        paid: true,
                        amountPaid: amount
                    ));

                    final AppSettings appSettings = await widget.firestoreService.getAppSettingsStream().first;
                    List<MonthlyDueItem> duesAfterPayment = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
                        Student(
                            id: student.id, name: student.name,
                            messStartDate: student.messStartDate,
                            originalServiceStartDate: student.originalServiceStartDate,
                            compensatoryDays: student.compensatoryDays,
                            currentCyclePaid: student.currentCyclePaid,
                            attendanceLog: student.attendanceLog,
                            paymentHistory: updatedHistory,
                            isArchived: student.isArchived
                        ),
                        appSettings.standardMonthlyFee,
                        DateTime.now()
                    );
                    double totalRemainingAfterThisPayment = duesAfterPayment.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
                    bool newCurrentCyclePaidFlag = totalRemainingAfterThisPayment <= 0;

                    try {
                      await widget.firestoreService.updateStudentPartial(student.id, {
                        'currentCyclePaid': newCurrentCyclePaidFlag,
                        'paymentHistory': updatedHistory.map((e) => e.toMap()).toList(),
                      });
                      if (!mounted) return;
                      Navigator.of(dlgContext).pop();
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
                    Navigator.of(dlgContext).pop();
                  }
                }),
          ],
        );
      },
    );
  }

  void _startNewServicePeriod(Student student) async {
    if (widget.userRole == UserRole.guest) return;
    if (student.isArchived) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot start new period for an archived student.'), backgroundColor: Colors.orange));
      return;
    }

    DateTime newStartDateForStudent = student.effectiveMessEndDate.add(Duration(days: 1));
    DateTime today = DateTime.now();
    DateTime firstOfThisMonth = DateTime(today.year, today.month, 1);

    if (newStartDateForStudent.isBefore(firstOfThisMonth) &&
        !(newStartDateForStudent.year == firstOfThisMonth.year && newStartDateForStudent.month == firstOfThisMonth.month)) {
      newStartDateForStudent = firstOfThisMonth;
    }

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

  List<Widget> _getAttendanceMarkersForDay(DateTime day, Map<DateTime, List<AttendanceStatus>> eventsMap) {
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
                    firstDay: student.originalServiceStartDate.subtract(Duration(days: 90)),
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
                    headerStyle: HeaderStyle(
                        formatButtonVisible: true,
                        titleCentered: true
                    ),
                  ),
                ),
                actions: <Widget>[ TextButton(child: Text("Close"), onPressed: () => Navigator.of(context).pop()) ],
              );
            }
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
                Navigator.pop(context, true);
                return true;
              },
              child: Scaffold(
                appBar: AppBar(
                  title: Hero(
                      tag: 'student_name_${student.id}', // Ensure tag is unique if coming from archived list
                      child: Material(
                          type: MaterialType.transparency,
                          child: Text(student.name + (student.isArchived ? " (Archived)" : "")) // Indicate if archived
                      )
                  ),
                  actions: [
                    if (isOwner && !student.isArchived) // Show Archive button only if not archived
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
                body: Opacity( // Dim content slightly if archived, as a visual cue
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
                            if (!student.isArchived) // Only show if not archived
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
                                            final entry = student.paymentHistory.reversed.toList()[idx];
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

                        if (isOwner && !student.isArchived) // Only show if not archived
                          _buildDetailCard(context, title: 'Manage Compensatory Days', icon: Icons.control_point_duplicate_outlined, children: [
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

                        if (isOwner && !student.isArchived) // Only show if not archived
                          ElevatedButton.icon(
                              icon: Icon(Icons.event_repeat),
                              label: Text('Start New Service Period'),
                              onPressed: () => _startNewServicePeriod(student),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12))),
                        SizedBox(height: 20),
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
