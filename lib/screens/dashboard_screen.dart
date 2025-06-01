// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/user_model.dart'; // Import UserRole
import '../services/firestore_service.dart';

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
        stream: firestoreService.getStudentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final students = snapshot.data ?? [];
          return _buildDashboardContent(context, students);
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<Student> students) {
    int activeStudentsCount = students.where((s) => s.effectiveMessEndDate.isAfter(DateTime.now())).length;
    int paymentsDueCount = 0;
    if (userRole == UserRole.owner) {
      paymentsDueCount = students.where((s) {
        bool nearingEndUnpaid = s.effectiveMessEndDate.isAfter(DateTime.now()) &&
            s.effectiveMessEndDate.difference(DateTime.now()).inDays <= 7 &&
            !s.currentCyclePaid;
        bool endedUnpaid = s.effectiveMessEndDate.isBefore(DateTime.now()) && !s.currentCyclePaid;
        return (nearingEndUnpaid || endedUnpaid) || (s.effectiveMessEndDate.isAfter(DateTime.now()) && !s.currentCyclePaid);
      }).length;
    }


    DateTime today = DateTime.now();
    int presentTodayCount = 0;
    int totalActiveTodayForAttendance = 0;

    for (var student in students) {
      DateTime serviceStartDateNormalized = DateTime(student.messStartDate.year, student.messStartDate.month, student.messStartDate.day);
      DateTime serviceEndDateNormalized = DateTime(student.effectiveMessEndDate.year, student.effectiveMessEndDate.month, student.effectiveMessEndDate.day);
      DateTime todayNormalized = DateTime(today.year, today.month, today.day);

      bool isActiveToday = (todayNormalized.isAtSameMomentAs(serviceStartDateNormalized) || todayNormalized.isAfter(serviceStartDateNormalized)) &&
          (todayNormalized.isAtSameMomentAs(serviceEndDateNormalized) || todayNormalized.isBefore(serviceEndDateNormalized));

      if (isActiveToday) {
        totalActiveTodayForAttendance++;
        bool wasPresent = student.attendanceLog.any((entry) {
          DateTime entryDateNormalized = DateTime(entry.date.year, entry.date.month, entry.date.day);
          return entryDateNormalized.isAtSameMomentAs(todayNormalized) &&
              entry.status == AttendanceStatus.present;
        });
        if (wasPresent) {
          presentTodayCount++;
        }
      }
    }
    String attendanceTodayText = "$presentTodayCount/$totalActiveTodayForAttendance";


    List<Student> monthEndStudentNotifications = students.where((s) {
      final diff = s.effectiveMessEndDate.difference(DateTime.now()).inDays;
      if (userRole == UserRole.owner) {
        return (diff >= 0 && diff <= 7) || (diff < 0 && !s.currentCyclePaid);
      } else {
        return (diff >= 0 && diff <= 7);
      }
    }).toList();
    monthEndStudentNotifications.sort((a,b) => a.effectiveMessEndDate.compareTo(b.effectiveMessEndDate));

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

                firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, 'Active Students', activeStudentsCount.toString(), Icons.person_outline, Theme.of(context).primaryColor, onTap: onNavigateToStudentsScreen)));
                firstRowWidgets.add(SizedBox(width: 10));

                if (userRole == UserRole.owner) {
                  firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, 'Payment Due', paymentsDueCount.toString(), Icons.credit_card_off_outlined, Theme.of(context).primaryColor, onTap: onNavigateToPaymentsScreenFiltered)));

                  if (!isNarrowScreen) {
                    firstRowWidgets.add(SizedBox(width: 10));
                    firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, 'Attendance Today', attendanceTodayText, Icons.event_available_outlined, Theme.of(context).primaryColor, onTap: onNavigateToAttendance)));
                  } else {
                    secondRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, 'Attendance Today', attendanceTodayText, Icons.event_available_outlined, Theme.of(context).primaryColor, onTap: onNavigateToAttendance, isFullWidth: true)));
                  }
                } else {
                  firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(context, 'Attendance Today', attendanceTodayText, Icons.event_available_outlined, Theme.of(context).primaryColor, onTap: onNavigateToAttendance)));
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

          Text('Upcoming Cycle Endings:', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          SizedBox(height: 10),
          monthEndStudentNotifications.isEmpty
              ? Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: Text('No upcoming cycle endings${userRole == UserRole.owner ? " or overdue payments" : ""}.', style: TextStyle(fontSize: 15))),
            ),
          )
              : Column(
            children: monthEndStudentNotifications.map<Widget>((student) {
              String subtitleText = 'Mess ends on: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}';
              if (userRole == UserRole.owner) {
                subtitleText += (student.effectiveMessEndDate.isBefore(DateTime.now()) && !student.currentCyclePaid ? ' (Payment Overdue)' :
                (!student.currentCyclePaid ? ' (Payment Pending)' : ' (Paid)'));
              }
              return Card(
                elevation: 1, margin: EdgeInsets.symmetric(vertical: 5),
                color: Colors.pink.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.red.shade600,
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
                  // Alignment(0.5, 0.0) means 75% from the left edge of this Expanded widget.
                  // Alignment.centerRight would be Alignment(1.0, 0.0)
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
