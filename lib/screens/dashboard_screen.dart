// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../models/app_settings_model.dart';
import '../utils/payment_manager.dart';

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
        // The stream now defaults to active students from FirestoreService
        stream: firestoreService.getStudentsStream(archiveStatusFilter: StudentArchiveStatusFilter.active),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (studentSnapshot.hasError) {
            return Center(child: Text('Error loading students: ${studentSnapshot.error}'));
          }
          final students = studentSnapshot.data ?? [];

          // Add FutureBuilder for AppSettings here
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

              // Pass students and standardMonthlyFee to _buildDashboardContent
              return _buildDashboardContent(context, students, standardMonthlyFee);
            },
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<Student> students, double standardMonthlyFee) {
    // 'students' list already contains only active, non-archived students due to the stream filter.
    int activeStudentsCount = students.where((s) => s.effectiveMessEndDate.isAfter(DateTime.now())).length;

    // New calculation for paymentsDueCount using PaymentManager
    int newPaymentsDueCount = 0;
    if (userRole == UserRole.owner) {
      for (var student in students) { // Iterate over already filtered active students
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

    // --- Time-aware Attendance Logic ---
    DateTime now = DateTime.now();
    MealType currentMealType;
    String mealTypeLabel;

    // Determine current meal type based on time (e.g., cutoff at 3 PM / 15:00 hours)
    // You can adjust this cutoff time as needed.
    // For example, morning meal cutoff could be 3 PM (15:00)
    if (now.hour < 15) { // Before 3 PM is considered morning meal time
      currentMealType = MealType.morning;
      mealTypeLabel = "Morning";
    } else { // 3 PM or later is considered night meal time
      currentMealType = MealType.night;
      mealTypeLabel = "Night";
    }

    DateTime todayForAttendance = DateTime(now.year, now.month, now.day); // Normalized today for precise comparison
    int presentTodayCount = 0;
    int totalActiveTodayForAttendance = 0;

    for (var student in students) { // Iterate over already filtered active students
      DateTime serviceStartDateNormalized = DateTime(student.messStartDate.year, student.messStartDate.month, student.messStartDate.day);
      DateTime serviceEndDateNormalized = DateTime(student.effectiveMessEndDate.year, student.effectiveMessEndDate.month, student.effectiveMessEndDate.day);

      // Check if student is active today (service period includes today)
      // Ensure comparison is date-only by normalizing 'todayForAttendance'
      bool isActiveToday = !todayForAttendance.isBefore(serviceStartDateNormalized) &&
          !todayForAttendance.isAfter(serviceEndDateNormalized);


      if (isActiveToday) {
        totalActiveTodayForAttendance++;
        // Check if student was present for the *current* meal type today
        bool wasPresentForCurrentMeal = student.attendanceLog.any((entry) {
          DateTime entryDateNormalized = DateTime(entry.date.year, entry.date.month, entry.date.day);
          return entryDateNormalized.isAtSameMomentAs(todayForAttendance) &&
              entry.status == AttendanceStatus.present &&
              entry.mealType == currentMealType; // Filter by currentMealType
        });
        if (wasPresentForCurrentMeal) {
          presentTodayCount++;
        }
      }
    }
    String attendanceTodayText = "$presentTodayCount/$totalActiveTodayForAttendance";
    // --- End of Time-aware Attendance Logic ---

    // Updated logic for "Upcoming Cycle Endings" notifications
    List<Map<String, dynamic>> studentNotificationsData = [];
    for (var student in students) { // Iterate over already filtered active students
      final diffDays = student.effectiveMessEndDate.difference(DateTime.now()).inDays;
      List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
          student, standardMonthlyFee, DateTime.now());
      double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
      bool isUnpaid = totalRemaining > 0;

      bool shouldDisplay = false;
      if (userRole == UserRole.owner) {
        // Display if nearing end (0-7 days), OR if service ended (diffDays < 0) and still unpaid
        if ((diffDays >= 0 && diffDays <= 7) || (diffDays < 0 && isUnpaid)) {
          shouldDisplay = true;
        }
      } else { // Guest
        if (diffDays >= 0 && diffDays <= 7) { // Guests only see nearing end
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
                String attendanceCardTitle = 'Attendance ($mealTypeLabel)'; // Dynamic title for the attendance card

                firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, 'Active Students', activeStudentsCount.toString(), Icons.person_outline, Theme.of(context).primaryColor, onTap: onNavigateToStudentsScreen)));
                firstRowWidgets.add(SizedBox(width: 10));

                if (userRole == UserRole.owner) {
                  // Use newPaymentsDueCount here
                  firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, 'Payment Due', newPaymentsDueCount.toString(), Icons.credit_card_off_outlined, Theme.of(context).primaryColor, onTap: onNavigateToPaymentsScreenFiltered)));

                  if (!isNarrowScreen) {
                    firstRowWidgets.add(SizedBox(width: 10));
                    // Use attendanceCardTitle here for Owner
                    firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, attendanceCardTitle, attendanceTodayText, Icons.event_available_outlined, Theme.of(context).primaryColor, onTap: onNavigateToAttendance)));
                  } else {
                    // Use attendanceCardTitle here for Owner (narrow screen)
                    secondRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, attendanceCardTitle, attendanceTodayText, Icons.event_available_outlined, Theme.of(context).primaryColor, onTap: onNavigateToAttendance, isFullWidth: true)));
                  }
                } else { // Guest role
                  // Use attendanceCardTitle here for Guest
                  firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, attendanceCardTitle, attendanceTodayText, Icons.event_available_outlined, Theme.of(context).primaryColor, onTap: onNavigateToAttendance)));
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
                      label: Text('Add Student', style: TextStyle(fontSize: 14)),
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
              Color cardColor = Colors.pink.shade50; // Default for nearing end

              if (userRole == UserRole.owner) {
                if (diffDays < 0 && isUnpaid) { // Service ended and unpaid
                  subtitleText += ' (Payment Overdue: ₹${totalRemaining.toStringAsFixed(0)})';
                  cardColor = Colors.red.shade100; // More prominent for overdue
                } else if (isUnpaid) { // Active or nearing end, and unpaid
                  subtitleText += ' (Payment Pending: ₹${totalRemaining.toStringAsFixed(0)})';
                  cardColor = Colors.orange.shade100; // Warning for pending
                } else { // Paid
                  subtitleText += ' (Paid)';
                  cardColor = Colors.green.shade50; // Success for paid
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
      {VoidCallback? onTap, bool isFullWidth = false}) {
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
              // Left Part: Icon and Title
              Expanded(
                flex: 3, // Icon and title take up roughly 3 parts of the space
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) ...[
                      Icon(icon, size: 28, color: Colors.white.withOpacity(0.9)),
                      SizedBox(height: 6),
                    ],
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
              // Right Part: Value (Count)
              Expanded(
                flex: 2, // Value (count) takes up roughly 2 parts of the space
                child: Align(
                  // Align the text slightly off-center to the right within its allocated space.
                  alignment: Alignment(0.5, 0.0),
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center, // Center text if it wraps (less likely for single digit)
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
