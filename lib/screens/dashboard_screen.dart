// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

class DashboardScreen extends StatelessWidget {
  final FirestoreService firestoreService;
  final VoidCallback onNavigateToAttendance;
  final VoidCallback onNavigateToStudentsScreen;
  final VoidCallback onNavigateToPaymentsScreenFiltered;
  final VoidCallback onNavigateToAddStudent;
  final Function(Student) onViewStudentDetails;

  final String ownerName = "Owner";

  DashboardScreen({
    required this.firestoreService,
    required this.onNavigateToAttendance,
    required this.onNavigateToStudentsScreen,
    required this.onNavigateToPaymentsScreenFiltered,
    required this.onNavigateToAddStudent,
    required this.onViewStudentDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
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
    int paymentsDueCount = students.where((s) {
      bool nearingEndUnpaid = s.effectiveMessEndDate.isAfter(DateTime.now()) &&
          s.effectiveMessEndDate.difference(DateTime.now()).inDays <= 7 &&
          !s.currentCyclePaid;
      bool endedUnpaid = s.effectiveMessEndDate.isBefore(DateTime.now()) && !s.currentCyclePaid;
      return (nearingEndUnpaid || endedUnpaid) || (s.effectiveMessEndDate.isAfter(DateTime.now()) && !s.currentCyclePaid);
    }).length;

    DateTime today = DateTime.now();
    int presentTodayCount = 0;
    for (var student in students) {
      bool isActiveToday = student.messStartDate.isBefore(today.add(Duration(days:1))) &&
          student.effectiveMessEndDate.isAfter(today.subtract(Duration(microseconds: 1)));
      if (isActiveToday) {
        bool wasPresent = student.attendanceLog.any((entry) =>
        entry.date.year == today.year &&
            entry.date.month == today.month &&
            entry.date.day == today.day &&
            entry.status == AttendanceStatus.present);
        if (wasPresent) {
          presentTodayCount++;
        }
      }
    }

    List<Student> monthEndStudentNotifications = students.where((s) {
      final diff = s.effectiveMessEndDate.difference(DateTime.now()).inDays;
      return (diff >= 0 && diff <= 7) || (diff < 0 && !s.currentCyclePaid);
    }).toList();
    monthEndStudentNotifications.sort((a,b) => a.effectiveMessEndDate.compareTo(b.effectiveMessEndDate));

    return Container(
      color: Colors.grey[100],
      child: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          Text('Hello, $ownerName!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
          SizedBox(height: 20),

          // Row 1: Horizontal Overview Cards - Adjusted Layout
          LayoutBuilder(
              builder: (context, constraints) {
                // Define a threshold for when to switch layouts
                bool isNarrowScreen = constraints.maxWidth < 500; // Adjusted breakpoint

                if (isNarrowScreen) {
                  // 2 cards in the first row, 1 card in the second row
                  return Column(
                    children: [
                      Row(
                        children: <Widget>[
                          Expanded(child: _buildSimpleSummaryCard(context, 'Active Students', activeStudentsCount.toString(), Icons.person_outline, Theme.of(context).primaryColor, onTap: onNavigateToStudentsScreen)),
                          SizedBox(width: 10),
                          Expanded(child: _buildSimpleSummaryCard(context, 'Payment Due', paymentsDueCount.toString(), Icons.credit_card_off_outlined, Theme.of(context).primaryColor, onTap: onNavigateToPaymentsScreenFiltered)),
                        ],
                      ),
                      SizedBox(height: 10),
                      _buildSimpleSummaryCard(context, 'Attendance Today', "$presentTodayCount Present", Icons.event_available_outlined, Theme.of(context).primaryColor, onTap: onNavigateToAttendance, isFullWidth: true),
                    ],
                  );
                } else {
                  // 3 cards in a single row for wider screens
                  return Row(
                    children: <Widget>[
                      Expanded(child: _buildSimpleSummaryCard(context, 'Active Students', activeStudentsCount.toString(), Icons.person_outline, Theme.of(context).primaryColor, onTap: onNavigateToStudentsScreen)),
                      SizedBox(width: 10),
                      Expanded(child: _buildSimpleSummaryCard(context, 'Payment Due', paymentsDueCount.toString(), Icons.credit_card_off_outlined, Theme.of(context).primaryColor, onTap: onNavigateToPaymentsScreenFiltered)),
                      SizedBox(width: 10),
                      Expanded(child: _buildSimpleSummaryCard(context, 'Attendance Today', "$presentTodayCount Present", Icons.event_available_outlined, Theme.of(context).primaryColor, onTap: onNavigateToAttendance)),
                    ],
                  );
                }
              }
          ),
          SizedBox(height: 30),

          Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black54)),
          SizedBox(height: 15),
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
          SizedBox(height: 30),

          Text('Upcoming Cycle Endings:', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          SizedBox(height: 10),
          monthEndStudentNotifications.isEmpty
              ? Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: Text('No upcoming cycle endings or overdue payments.', style: TextStyle(fontSize: 15))),
            ),
          )
              : Column(
            children: monthEndStudentNotifications.map<Widget>((student) {
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
                  subtitle: Text('Mess ends on: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}' +
                      (student.effectiveMessEndDate.isBefore(DateTime.now()) && !student.currentCyclePaid ? ' (Payment Overdue)' :
                      (!student.currentCyclePaid ? ' (Payment Pending)' : ' (Paid)')),
                      style: TextStyle(color: Colors.black87)),
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
      {VoidCallback? onTap, bool isFullWidth = false}
      ) {
    // Using IntrinsicHeight to allow cards to size their height to their content
    // This will help avoid overflow if text is larger or wraps.
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container( // Use Container to allow IntrinsicHeight to work
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0), // Adjusted padding
          width: isFullWidth ? double.infinity : null, // Take full width if specified
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Important for Column to not take infinite height
            children: <Widget>[
              if (icon != null) ...[
                Icon(icon, size: 28, color: Colors.white.withOpacity(0.8)), // Slightly larger icon
                SizedBox(height: 8),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600), // Adjusted style
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold), // Adjusted style
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
