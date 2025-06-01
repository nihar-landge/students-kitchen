// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

import 'dashboard_screen.dart';
import 'students_screen.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';
import 'attendance_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  final UserRole userRole;

  MainScreen({required this.userRole, Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  String? _initialPaymentsFilter;

  late List<Widget> _widgetOptions;
  late List<BottomNavigationBarItem> _navBarItems;

  // These navigation methods are now primarily for Dashboard actions
  // StudentsScreen will handle its own internal navigation for add/view details
  void _navigateToAddStudentFromDashboard() {
    if (widget.userRole == UserRole.owner) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddStudentScreen(firestoreService: _firestoreService)),
      );
    }
  }

  void _navigateToStudentDetailFromDashboard(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          studentId: student.id,
          firestoreService: _firestoreService,
          userRole: widget.userRole,
        ),
      ),
    );
  }

  void _navigateToAttendanceScreen() {
    int attendanceIndex = _navBarItems.indexWhere((item) => item.label == 'Attendance');
    if (attendanceIndex != -1 && _selectedIndex != attendanceIndex) {
      setStateIfMounted(() { _selectedIndex = attendanceIndex; });
    }
  }

  void _navigateToStudentsScreenTab() {
    int studentsIndex = _navBarItems.indexWhere((item) => item.label == 'Students');
    if (studentsIndex != -1 && _selectedIndex != studentsIndex) {
      setStateIfMounted(() { _selectedIndex = studentsIndex; });
    }
  }

  void _navigateToPaymentsScreenFiltered() {
    if (widget.userRole == UserRole.owner) {
      int paymentsIndex = _navBarItems.indexWhere((item) => item.label == 'Payments');
      if (paymentsIndex != -1) {
        setStateIfMounted(() {
          _initialPaymentsFilter = "Dues > 0";
          _selectedIndex = paymentsIndex;
        });
      }
    }
  }

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  @override
  void initState() {
    super.initState();
    _buildNavItemsAndWidgetOptions();
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userRole != oldWidget.userRole) {
      _buildNavItemsAndWidgetOptions();
      if (_selectedIndex >= _widgetOptions.length && _widgetOptions.isNotEmpty) {
        _selectedIndex = 0;
      } else if (_widgetOptions.isEmpty) {
        _selectedIndex = 0;
      }
    }
  }

  void _buildNavItemsAndWidgetOptions() {
    _navBarItems = [];
    _widgetOptions = [];

    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'));
    _widgetOptions.add(DashboardScreen(
      firestoreService: _firestoreService,
      userRole: widget.userRole,
      onNavigateToAttendance: _navigateToAttendanceScreen,
      onNavigateToStudentsScreen: _navigateToStudentsScreenTab,
      onNavigateToPaymentsScreenFiltered: _navigateToPaymentsScreenFiltered,
      onNavigateToAddStudent: _navigateToAddStudentFromDashboard, // For dashboard's quick action
      onViewStudentDetails: _navigateToStudentDetailFromDashboard, // For dashboard's quick action
    ));

    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Students'));
    // **** MODIFIED HERE: Removed onAddStudent and onViewStudent ****
    _widgetOptions.add(StudentsScreen(
      firestoreService: _firestoreService,
      userRole: widget.userRole,
      // onAddStudent: () => _navigateToAddStudent(context), // REMOVED
      // onViewStudent: (student) => _navigateToStudentDetail(context, student), // REMOVED
    ));
    // **** END OF MODIFICATION ****

    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Attendance'));
    _widgetOptions.add(AttendanceScreen(
        firestoreService: _firestoreService,
        userRole: widget.userRole
    ));

    if (widget.userRole == UserRole.owner) {
      _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.payment_outlined), activeIcon: Icon(Icons.payment), label: 'Payments'));
      _widgetOptions.add(PaymentsScreen(
        key: ValueKey('payments_screen_filter_$_initialPaymentsFilter'),
        firestoreService: _firestoreService,
        onViewStudent: _navigateToStudentDetailFromDashboard, // Payments screen might still need this
        initialFilterOption: _initialPaymentsFilter,
      ));

      _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'));
      _widgetOptions.add(SettingsScreen(
          firestoreService: _firestoreService,
          userRole: widget.userRole
      ));
    }

    if (_selectedIndex >= _widgetOptions.length && _widgetOptions.isNotEmpty) {
      _selectedIndex = 0;
    } else if (_widgetOptions.isEmpty) {
      _selectedIndex = 0;
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setStateIfMounted(() {
      if (index < _navBarItems.length) {
        String tappedLabel = _navBarItems[index].label!;
        if (tappedLabel != 'Payments') {
          _initialPaymentsFilter = null;
        }
        _selectedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_navBarItems.isEmpty || _widgetOptions.isEmpty) {
      _buildNavItemsAndWidgetOptions();
    }

    if (_widgetOptions.isEmpty) {
      return Scaffold(
        body: Center(child: Text("Loading application...")),
      );
    }

    int currentSelectedIndex = _selectedIndex;
    if (currentSelectedIndex >= _widgetOptions.length) {
      currentSelectedIndex = _widgetOptions.isNotEmpty ? 0 : 0;
    }

    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (Widget child, Animation<double> primaryAnimation, Animation<double> secondaryAnimation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.30),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: primaryAnimation,
                curve: Curves.easeInOutCubic,
              ),
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: primaryAnimation,
                curve: Curves.easeInOutCubic,
              ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey('screen_${currentSelectedIndex}_role_${widget.userRole.index}'),
          child: _widgetOptions.elementAt(currentSelectedIndex),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _navBarItems,
        currentIndex: currentSelectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}
