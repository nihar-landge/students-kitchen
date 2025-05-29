// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

class DashboardScreen extends StatelessWidget {
  final FirestoreService firestoreService;
  final VoidCallback onNavigateToAttendance;
  final VoidCallback onNavigateToStudents;
  final Function(Student) onViewStudentDetails;
  final String ownerName = "Owner";

  DashboardScreen({
    required this.firestoreService,
    required this.onNavigateToAttendance,
    required this.onNavigateToStudents,
    required this.onViewStudentDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: StreamBuilder<List<Student>>(
        stream: firestoreService.getStudentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final students = snapshot.data ?? []; // Provide an empty list if data is null
          return _buildDashboardContent(context, students, onNavigateToAttendance, onNavigateToStudents, onViewStudentDetails, ownerName);
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<Student> students, VoidCallback navAttend, VoidCallback navStudents, Function(Student) viewDetails, String owner) {
    int activeStudentsCount = students.where((s) => s.effectiveMessEndDate.isAfter(DateTime.now())).length;
    int paymentsDueCount = students.where((s) {
      bool nearingEnd = s.effectiveMessEndDate.isAfter(DateTime.now()) && s.effectiveMessEndDate.difference(DateTime.now()).inDays <= 7;
      bool endedUnpaid = s.effectiveMessEndDate.isBefore(DateTime.now()) && !s.currentCyclePaid;
      return (nearingEnd && !s.currentCyclePaid) || endedUnpaid;
    }).length;
    String attendanceMarkedToday = "N/A";

    List<Student> monthEndNotifications = students.where((s) {
      final diff = s.effectiveMessEndDate.difference(DateTime.now()).inDays;
      return (diff >= 0 && diff <= 5) || (diff < 0 && !s.currentCyclePaid);
    }).toList();

    return ListView(
      padding: EdgeInsets.all(16.0),
      children: <Widget>[
        Text('Hello, $owner!', style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: 20),
        Wrap(
          spacing: 10.0, runSpacing: 10.0,
          children: <Widget>[
            _buildSummaryCard(context, 'Active Students', activeStudentsCount.toString(), Icons.person, Colors.blue),
            _buildSummaryCard(context, 'Payments Due', paymentsDueCount.toString(), Icons.payment, Colors.orange),
            _buildSummaryCard(context, 'Attendance Today', attendanceMarkedToday, Icons.event_available, Colors.green, isSmallText: true),
          ],
        ),
        SizedBox(height: 30),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            ElevatedButton.icon(icon: Icon(Icons.edit_calendar), label: Text('Mark Attendance'), onPressed: navAttend, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 16, vertical:12))),
            ElevatedButton.icon(icon: Icon(Icons.people_alt), label: Text('View Students'), onPressed: navStudents, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 16, vertical:12))),
          ],
        ),
        SizedBox(height: 30),
        Text('Month End Notifications', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 10),
        monthEndNotifications.isEmpty
            ? Center(child: Text('No immediate month end notifications.'))
            : Column(
          children: monthEndNotifications.map<Widget>((student) { // Explicitly map to Widget
            return Card(
              elevation: 2, margin: EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Icon(
                  student.effectiveMessEndDate.isBefore(DateTime.now()) ? Icons.warning_amber_rounded : Icons.notification_important_outlined,
                  color: student.effectiveMessEndDate.isBefore(DateTime.now()) ? Colors.redAccent : Colors.orangeAccent,
                ),
                title: Text(student.name),
                subtitle: Text('Mess ends on: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}' + (student.effectiveMessEndDate.isBefore(DateTime.now()) && !student.currentCyclePaid ? ' (Payment Pending)' : '')),
                trailing: Icon(Icons.arrow_forward_ios),
                onTap: () => viewDetails(student),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color, {bool isSmallText = false}) {
    return Card(
      color: color.withOpacity(0.1),
      child: Container(
        width: MediaQuery.of(context).size.width / 2 - 30,
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 30, color: color),
            SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
            SizedBox(height: 5),
            Text(value, style: isSmallText ? Theme.of(context).textTheme.bodyMedium : Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
