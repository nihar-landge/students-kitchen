// lib/screens/main_screen.dart
import 'package:flutter/material.dart';

// Models and Services
import '../models/student_model.dart'; // For Student type
import '../services/firestore_service.dart';

// Screen imports
import 'dashboard_screen.dart';
import 'students_screen.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';
import 'attendance_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';


class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();

  void _navigateToAddStudent(BuildContext navContext) async {
    await Navigator.push(
      navContext,
      MaterialPageRoute(builder: (context) => AddStudentScreen(firestoreService: _firestoreService)),
    );
  }

  void _navigateToStudentDetail(BuildContext navContext, Student student) async {
    await Navigator.push(
      navContext,
      MaterialPageRoute(builder: (context) => StudentDetailScreen(studentId: student.id, firestoreService: _firestoreService)),
    );
  }

  void _navigateToAttendanceScreen() {
    setState(() { _selectedIndex = 2; });
  }

  void _navigateToStudentsScreenTab() {
    setState(() { _selectedIndex = 1; });
  }

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      DashboardScreen(
        firestoreService: _firestoreService,
        onNavigateToAttendance: _navigateToAttendanceScreen,
        onNavigateToStudents: _navigateToStudentsScreenTab,
        onViewStudentDetails: (student) => _navigateToStudentDetail(context, student),
      ),
      StudentsScreen(
        firestoreService: _firestoreService,
        onAddStudent: () => _navigateToAddStudent(context),
        onViewStudent: (student) => _navigateToStudentDetail(context, student),
      ),
      AttendanceScreen(firestoreService: _firestoreService),
      PaymentsScreen(firestoreService: _firestoreService, onViewStudent: (student) => _navigateToStudentDetail(context, student)),
      SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.payment_outlined), activeIcon: Icon(Icons.payment), label: 'Payments'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal[800],
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}
