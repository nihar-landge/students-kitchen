// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

// Ensure direct and unambiguous imports
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

// Import each screen directly
import 'dashboard_screen.dart';   // Ensure this file's DashboardScreen constructor accepts userRole
import 'students_screen.dart';    // Ensure this file's StudentsScreen constructor accepts userRole
import 'add_student_screen.dart';
import 'student_detail_screen.dart';
import 'attendance_screen.dart';  // Ensure this file's AttendanceScreen constructor accepts userRole
import 'payments_screen.dart';
import 'settings_screen.dart';    // Ensure this file's SettingsScreen constructor accepts userRole

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

  void _navigateToAddStudent(BuildContext navContext) async {
    if (widget.userRole == UserRole.owner) {
      await Navigator.push(
        navContext,
        MaterialPageRoute(builder: (context) => AddStudentScreen(firestoreService: _firestoreService)),
      );
    }
  }

  void _navigateToStudentDetail(BuildContext navContext, Student student) async {
    await Navigator.push(
      navContext,
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
    if (attendanceIndex != -1) {
      setStateIfMounted(() { _selectedIndex = attendanceIndex; });
    }
  }

  void _navigateToStudentsScreenTab() {
    int studentsIndex = _navBarItems.indexWhere((item) => item.label == 'Students');
    if (studentsIndex != -1) {
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
    }
  }

  void _buildNavItemsAndWidgetOptions() {
    _navBarItems = [];
    _widgetOptions = [];

    // Dashboard - Always available
    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'));
    _widgetOptions.add(DashboardScreen( // Instantiating DashboardScreen
      firestoreService: _firestoreService,
      userRole: widget.userRole, // Passing userRole
      onNavigateToAttendance: _navigateToAttendanceScreen,
      onNavigateToStudentsScreen: _navigateToStudentsScreenTab,
      onNavigateToPaymentsScreenFiltered: _navigateToPaymentsScreenFiltered,
      onNavigateToAddStudent: () => _navigateToAddStudent(context),
      onViewStudentDetails: (student) => _navigateToStudentDetail(context, student),
    ));

    // Students - Always available
    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Students'));
    _widgetOptions.add(StudentsScreen( // Instantiating StudentsScreen
      firestoreService: _firestoreService,
      userRole: widget.userRole, // Passing userRole
      onAddStudent: () => _navigateToAddStudent(context),
      onViewStudent: (student) => _navigateToStudentDetail(context, student),
    ));

    // Attendance - Always available
    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Attendance'));
    _widgetOptions.add(AttendanceScreen(
        firestoreService: _firestoreService,
        userRole: widget.userRole // Passing userRole
    ));

    if (widget.userRole == UserRole.owner) {
      // Payments - Owner only
      _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.payment_outlined), activeIcon: Icon(Icons.payment), label: 'Payments'));
      _widgetOptions.add(PaymentsScreen(
        key: ValueKey(_initialPaymentsFilter ?? 'default_payments_key_owner_${DateTime.now().millisecondsSinceEpoch}'),
        firestoreService: _firestoreService,
        onViewStudent: (student) => _navigateToStudentDetail(context, student),
        initialFilterOption: _initialPaymentsFilter,
      ));

      // Settings - Owner only
      _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'));
      _widgetOptions.add(SettingsScreen(userRole: widget.userRole)); // Passing userRole
    }

    if (_selectedIndex >= _widgetOptions.length && _widgetOptions.isNotEmpty) {
      _selectedIndex = _widgetOptions.length - 1;
    } else if (_widgetOptions.isEmpty) { // Should not happen if dashboard/students/attendance are always there
      _selectedIndex = 0;
    }
    if (_selectedIndex >= _widgetOptions.length) {
      _selectedIndex = 0;
    }
  }

  void _onItemTapped(int index) {
    setStateIfMounted(() {
      if (index < _navBarItems.length) {
        String tappedLabel = _navBarItems[index].label!;
        if (widget.userRole == UserRole.owner) {
          if (tappedLabel != 'Payments') {
            _initialPaymentsFilter = null;
          }
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
        body: Center(child: Text("No options available for this role.")),
      );
    }

    int currentSelectedIndex = _selectedIndex;
    if (currentSelectedIndex >= _widgetOptions.length) {
      currentSelectedIndex = _widgetOptions.length -1;
      if (currentSelectedIndex < 0) currentSelectedIndex = 0;
    }

    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (Widget child, Animation<double> primaryAnimation, Animation<double> secondaryAnimation) {
          return SharedAxisTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>('selected_tab_${currentSelectedIndex}_role_${widget.userRole.index}_${DateTime.now().millisecondsSinceEpoch}'), // Ensure unique key
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
