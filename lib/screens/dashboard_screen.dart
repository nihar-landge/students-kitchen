// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart'; // Ensure Student, MealType, AttendanceStatus are defined here
import '../models/user_model.dart';   // Ensure UserRole is defined here
import '../services/firestore_service.dart';
import '../models/app_settings_model.dart'; // Ensure AppSettings is defined here
import '../utils/payment_manager.dart';  // Ensure PaymentManager and MonthlyDueItem are defined here

class DashboardScreen extends StatelessWidget {
  final FirestoreService firestoreService;
  final UserRole userRole;
  final VoidCallback onNavigateToAttendance;
  final VoidCallback onNavigateToStudentsScreen;
  final VoidCallback onNavigateToPaymentsScreenFiltered;
  final VoidCallback onNavigateToAddStudent;
  final Function(Student) onViewStudentDetails;

  final String ownerName = "Owner"; // This could be dynamic in a real app

  DashboardScreen({
    required this.firestoreService,
    required this.userRole,
    required this.onNavigateToAttendance,
    required this.onNavigateToStudentsScreen,
    required this.onNavigateToPaymentsScreenFiltered,
    required this.onNavigateToAddStudent,
    required this.onViewStudentDetails,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userRole == UserRole.owner ? 'Owner Dashboard' : 'Guest Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<Student>>(
        stream: firestoreService.getStudentsStream(archiveStatusFilter: StudentArchiveStatusFilter.active),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (studentSnapshot.hasError) {
            return Center(child: Text('Error loading students: ${studentSnapshot.error}'));
          }
          final students = studentSnapshot.data ?? [];

          return FutureBuilder<AppSettings>(
            future: firestoreService.getAppSettingsStream().first, // Fetch settings once
            builder: (context, appSettingsSnapshot) {
              if (appSettingsSnapshot.connectionState == ConnectionState.waiting && !appSettingsSnapshot.hasData) {
                return Center(child: CircularProgressIndicator(key: ValueKey("settings_loader_for_dashboard")));
              }
              if (appSettingsSnapshot.hasError) {
                return Center(child: Text('Error loading app settings: ${appSettingsSnapshot.error}'));
              }

              final standardMonthlyFee = appSettingsSnapshot.data?.standardMonthlyFee ?? 2000.0; // Default if not found

              return _buildDashboardContent(context, students, standardMonthlyFee);
            },
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<Student> students, double standardMonthlyFee) {
    int activeStudentsCount = students.where((s) => s.effectiveMessEndDate.isAfter(DateTime.now())).length;

    int newPaymentsDueCount = 0;
    if (userRole == UserRole.owner) {
      for (var student in students) {
        List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
            student,
            standardMonthlyFee,
            DateTime.now() // Calculate dues up to the current date
        );
        double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
        if (totalRemaining > 0) {
          newPaymentsDueCount++;
        }
      }
    }

    DateTime now = DateTime.now();
    MealType currentMealType;
    String mealTypeLabel; // Used for Owner's attendance card title

    if (now.hour < 16) { // Before 4 PM is considered morning meal time
      currentMealType = MealType.morning;
      mealTypeLabel = "Morning";
    } else { // 4 PM or later is considered night meal time
      currentMealType = MealType.night;
      mealTypeLabel = "Night";
    }

    DateTime todayForAttendance = DateTime(now.year, now.month, now.day);
    int presentTodayCount = 0;
    int totalActiveTodayForAttendance = 0;

    for (var student in students) {
      DateTime serviceStartDateNormalized = DateTime(student.messStartDate.year, student.messStartDate.month, student.messStartDate.day);
      DateTime serviceEndDateNormalized = DateTime(student.effectiveMessEndDate.year, student.effectiveMessEndDate.month, student.effectiveMessEndDate.day);

      bool isActiveToday = !todayForAttendance.isBefore(serviceStartDateNormalized) &&
          !todayForAttendance.isAfter(serviceEndDateNormalized);

      if (isActiveToday) {
        totalActiveTodayForAttendance++;
        bool wasPresentForCurrentMeal = student.attendanceLog.any((entry) {
          DateTime entryDateNormalized = DateTime(entry.date.year, entry.date.month, entry.date.day);
          return entryDateNormalized.isAtSameMomentAs(todayForAttendance) &&
              entry.status == AttendanceStatus.present &&
              entry.mealType == currentMealType;
        });
        if (wasPresentForCurrentMeal) {
          presentTodayCount++;
        }
      }
    }
    String attendanceTodayText = "$presentTodayCount/$totalActiveTodayForAttendance";

    List<Map<String, dynamic>> studentNotificationsData = [];
    for (var student in students) {
      final diffDays = student.effectiveMessEndDate.difference(DateTime.now()).inDays;
      List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
          student, standardMonthlyFee, DateTime.now());
      double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
      bool isUnpaid = totalRemaining > 0;

      bool shouldDisplay = false;
      if (userRole == UserRole.owner) {
        if ((diffDays >= 0 && diffDays <= 3) || (diffDays < 0 && isUnpaid)) {
          shouldDisplay = true;
        }
      } else { // Guest
        if (diffDays >= 0 && diffDays <= 3) { // Guests only see nearing end
          shouldDisplay = true;
        }
      }
      if (shouldDisplay) {
        studentNotificationsData.add({
          'student': student,
          'isUnpaid': isUnpaid,
          'totalRemaining': totalRemaining,
          'diffDays': diffDays,
        });
      }
    }
    studentNotificationsData.sort((a, b) {
      Student studentA = a['student'] as Student;
      Student studentB = b['student'] as Student;
      return studentA.effectiveMessEndDate.compareTo(studentB.effectiveMessEndDate);
    });

    return Container(
      color: Colors.grey[100],
      child: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          Text(userRole == UserRole.owner ? 'Hello, $ownerName!' : 'Welcome, Guest!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
          SizedBox(height: 20),

          LayoutBuilder(
              builder: (context, constraints) {
                bool isNarrowScreen = constraints.maxWidth < 550;
                List<Widget> firstRowWidgets = [];
                List<Widget> secondRowWidgets = [];

                String attendanceCardDisplayTitle;
                int attendanceIconFlex;
                int attendanceValueFlex;

                if (userRole == UserRole.owner) {
                  // MODIFICATION: Owner's attendance card gets a title
                  attendanceCardDisplayTitle = 'Check-in ($mealTypeLabel)';
                  attendanceIconFlex = 3; // Owner's attendance card uses 3:2 flex ratio
                  attendanceValueFlex = 2;
                } else { // Guest role
                  // MODIFICATION: Guest's attendance card has no title
                  attendanceCardDisplayTitle = "";
                  attendanceIconFlex = 2; // Guest's attendance card uses 2:8 (20:80) flex ratio
                  attendanceValueFlex = 8;
                }

                // Active Students card (uses 3:2 flex for both owner and guest, and has a title)
                firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                    context,
                    'Active Students',
                    activeStudentsCount.toString(),
                    Icons.person_outline,
                    Theme.of(context).primaryColor,
                    onTap: onNavigateToStudentsScreen,
                    iconFlexFactor: 3,
                    valueFlexFactor: 2
                )));
                firstRowWidgets.add(SizedBox(width: 10));

                if (userRole == UserRole.owner) {
                  // Payment Due card for Owner (uses 3:2 flex and has a title)
                  firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                      context,
                      'Payment Due',
                      newPaymentsDueCount.toString(),
                      Icons.credit_card_off_outlined,
                      Theme.of(context).primaryColor,
                      onTap: onNavigateToPaymentsScreenFiltered,
                      iconFlexFactor: 3,
                      valueFlexFactor: 2
                  )));

                  if (!isNarrowScreen) {
                    firstRowWidgets.add(SizedBox(width: 10));
                    // Attendance card for Owner
                    firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                        context,
                        attendanceCardDisplayTitle, // Owner gets title "Check-in (Morning/Night)"
                        attendanceTodayText,
                        Icons.event_available_outlined,
                        Theme.of(context).primaryColor,
                        onTap: onNavigateToAttendance,
                        iconFlexFactor: attendanceIconFlex, // Uses owner's 3:2
                        valueFlexFactor: attendanceValueFlex
                    )));
                  } else {
                    // Attendance card for Owner on narrow screen
                    secondRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                        context,
                        attendanceCardDisplayTitle, // Owner gets title "Check-in (Morning/Night)"
                        attendanceTodayText,
                        Icons.event_available_outlined,
                        Theme.of(context).primaryColor,
                        onTap: onNavigateToAttendance,
                        isFullWidth: true,
                        iconFlexFactor: attendanceIconFlex, // Uses owner's 3:2
                        valueFlexFactor: attendanceValueFlex
                    )));
                  }
                } else { // Guest role
                  // Attendance card for Guest
                  firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                      context,
                      attendanceCardDisplayTitle, // Empty title for Guest
                      attendanceTodayText,
                      Icons.event_available_outlined,
                      Theme.of(context).primaryColor,
                      onTap: onNavigateToAttendance,
                      iconFlexFactor: attendanceIconFlex, // Uses guest's 2:8
                      valueFlexFactor: attendanceValueFlex
                  )));
                }

                List<Widget> layoutChildren = [Row(children: firstRowWidgets)];
                if (secondRowWidgets.isNotEmpty) {
                  layoutChildren.add(SizedBox(height: 10));
                  layoutChildren.add(Row(children: secondRowWidgets));
                }
                return Column(children: layoutChildren);
              }
          ),
          SizedBox(height: 30),

          if (userRole == UserRole.owner)
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black54)),
          if (userRole == UserRole.owner) SizedBox(height: 15),
          if (userRole == UserRole.owner)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                      icon: Icon(Icons.person_add_alt_1, size: 20),
                      label: Text('Add', style: TextStyle(fontSize: 14)),
                      onPressed: onNavigateToAddStudent,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical:15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      )
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                      icon: Icon(Icons.edit_calendar_outlined, size: 20),
                      label: Text('Mark Attendance', style: TextStyle(fontSize: 14)),
                      onPressed: onNavigateToAttendance,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[400],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical:15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      )
                  ),
                ),
              ],
            ),
          if (userRole == UserRole.owner) SizedBox(height: 30),

          Text('Upcoming Cycle Endings / Dues:', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          SizedBox(height: 10),
          studentNotificationsData.isEmpty
              ? Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: Text('No upcoming cycle endings${userRole == UserRole.owner ? " or overdue payments" : ""}.', style: TextStyle(fontSize: 15))),
            ),
          )
              : Column(
            children: studentNotificationsData.map<Widget>((data) {
              final student = data['student'] as Student;
              final isUnpaid = data['isUnpaid'] as bool;
              final totalRemaining = data['totalRemaining'] as double;
              final diffDays = data['diffDays'] as int;

              String subtitleText = 'Mess ends on: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}';
              Color cardColor = Colors.pink.shade50;

              if (userRole == UserRole.owner) {
                if (diffDays < 0 && isUnpaid) {
                  subtitleText += ' (Payment Overdue: ₹${totalRemaining.toStringAsFixed(0)})';
                  cardColor = Colors.red.shade100;
                } else if (isUnpaid) {
                  subtitleText += ' (Payment Pending: ₹${totalRemaining.toStringAsFixed(0)})';
                  cardColor = Colors.orange.shade100;
                } else {
                  subtitleText += ' (Paid)';
                  cardColor = Colors.green.shade50;
                }
              }

              return Card(
                elevation: 1, margin: EdgeInsets.symmetric(vertical: 5),
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: Icon(
                    Icons.notifications_active_outlined,
                    color: isUnpaid ? (diffDays < 0 ? Colors.red.shade700 : Colors.orange.shade700) : Colors.green.shade700,
                  ),
                  title: Text(student.name, style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(subtitleText, style: TextStyle(color: Colors.black87)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                  onTap: () => onViewStudentDetails(student),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSummaryCard(
      BuildContext context,
      String title,
      String value,
      IconData? icon,
      Color cardColor,
      {VoidCallback? onTap,
        bool isFullWidth = false,
        int iconFlexFactor = 3,     // Default to owner's 3:2 preference
        int valueFlexFactor = 2      // Default to owner's 3:2 preference
      }) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(12.0),
          width: isFullWidth ? double.infinity : null,
          constraints: BoxConstraints(minHeight: 100),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: iconFlexFactor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null)
                      Icon(icon, size: 28, color: Colors.white.withOpacity(0.9)),
                    if (icon != null && title.isNotEmpty)
                      SizedBox(height: 10), // Vertical space
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: valueFlexFactor,
                child: Align(
                  alignment: Alignment(0.5, 0.0),
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}