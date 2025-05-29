// lib/screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

class AttendanceScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  AttendanceScreen({required this.firestoreService});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  MealType _selectedMealType = MealType.morning;
  Map<String, AttendanceStatus> _attendanceStatusMap = {};
  List<Student> _allActiveStudentsForDate = []; // All active students for the selected date
  List<Student> _displayedStudents = []; // Students to display after search/sort
  bool _isLoading = true;
  String _searchTerm = "";
  bool _sortAbsenteesTop = false;
  int _absentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadActiveStudentsAndInitializeAttendance();
  }

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  Future<void> _loadActiveStudentsAndInitializeAttendance() async {
    setStateIfMounted(() { _isLoading = true; });
    try {
      List<Student> allStudents = await widget.firestoreService.getStudentsStream().first;

      _allActiveStudentsForDate = allStudents.where((s) {
        return s.messStartDate.isBefore(_selectedDate.add(Duration(days: 1))) &&
            s.effectiveMessEndDate.isAfter(_selectedDate.subtract(Duration(microseconds: 1)));
      }).toList();

      _attendanceStatusMap.clear();
      for (var student in _allActiveStudentsForDate) {
        var existingEntry = student.attendanceLog.firstWhere(
                (entry) => entry.date.year == _selectedDate.year &&
                entry.date.month == _selectedDate.month &&
                entry.date.day == _selectedDate.day &&
                entry.mealType == _selectedMealType,
            orElse: () => AttendanceEntry(date: _selectedDate, mealType: _selectedMealType, status: AttendanceStatus.absent) // Default to Absent
        );
        _attendanceStatusMap[student.id] = existingEntry.status;
      }
      _filterAndSortDisplayedStudents(); // Initial filter and sort
    } catch (e) {
      if (!mounted) return;
      print("Error loading students for attendance: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading students: $e"), backgroundColor: Colors.red,));
    }
    setStateIfMounted(() { _isLoading = false; });
  }

  void _filterAndSortDisplayedStudents() {
    List<Student> tempStudents = List.from(_allActiveStudentsForDate);

    // Search
    if (_searchTerm.isNotEmpty) {
      String lowerSearchTerm = _searchTerm.toLowerCase();
      tempStudents = tempStudents.where((student) {
        return student.name.toLowerCase().contains(lowerSearchTerm) ||
            student.id.contains(lowerSearchTerm); // ID is contactNumber
      }).toList();
    }

    // Sort
    if (_sortAbsenteesTop) {
      tempStudents.sort((a, b) {
        bool isAAbsent = _attendanceStatusMap[a.id] == AttendanceStatus.absent;
        bool isBAbsent = _attendanceStatusMap[b.id] == AttendanceStatus.absent;
        if (isAAbsent && !isBAbsent) return -1; // a (absent) comes before b (present)
        if (!isAAbsent && isBAbsent) return 1;  // b (absent) comes before a (present)
        return a.name.compareTo(b.name); // Default sort by name
      });
    } else {
      tempStudents.sort((a, b) => a.name.compareTo(b.name)); // Default sort by name
    }

    _displayedStudents = tempStudents;
    _calculateAbsentCount(); // Update absent count based on displayed (could also be on _allActiveStudentsForDate based on requirement)
    // For now, let's count absentees from the currently displayed/searched list for clarity on screen
    setStateIfMounted((){});
  }

  void _calculateAbsentCount() {
    _absentCount = _displayedStudents.where((student) => _attendanceStatusMap[student.id] == AttendanceStatus.absent).length;
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context, initialDate: _selectedDate,
        firstDate: DateTime(2020), lastDate: DateTime.now().add(Duration(days: 7)));
    if (picked != null && picked != _selectedDate) {
      setStateIfMounted(() { _selectedDate = picked; });
      _loadActiveStudentsAndInitializeAttendance();
    }
  }

  void _saveAttendance() async {
    if (_allActiveStudentsForDate.isEmpty) { // Check against all active students, not just displayed ones
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No active students to save attendance for.')));
      return;
    }
    setStateIfMounted(() { _isLoading = true; });

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var student in _allActiveStudentsForDate) { // Iterate over all active students for the date
      final status = _attendanceStatusMap[student.id];
      if (status == null) continue;

      List<AttendanceEntry> updatedLog = List.from(student.attendanceLog);
      updatedLog.removeWhere((entry) =>
      entry.date.year == _selectedDate.year &&
          entry.date.month == _selectedDate.month &&
          entry.date.day == _selectedDate.day &&
          entry.mealType == _selectedMealType);
      updatedLog.add(AttendanceEntry(
          date: _selectedDate, mealType: _selectedMealType, status: status));

      DocumentReference studentRef = FirebaseFirestore.instance.collection('students').doc(student.id);
      batch.update(studentRef, {'attendanceLog': updatedLog.map((e) => e.toMap()).toList()});
    }

    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance saved successfully!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving attendance: $e'), backgroundColor: Colors.red));
    } finally {
      setStateIfMounted(() { _isLoading = false; });
      _loadActiveStudentsAndInitializeAttendance();
    }
  }

  void _markAll(AttendanceStatus status) {
    setStateIfMounted(() {
      for (var student in _displayedStudents) { // Mark all for currently displayed students
        _attendanceStatusMap[student.id] = status;
      }
      _calculateAbsentCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mark Attendance')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: <Widget>[
          Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(elevation: 2, child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                      Text('Date: ${DateFormat.yMMMd().format(_selectedDate)}', style: Theme.of(context).textTheme.titleMedium),
                      TextButton.icon(icon: Icon(Icons.calendar_month_outlined), label: Text('Change Date'), onPressed: () => _selectDate(context))
                    ]),
                    SizedBox(height: 10),
                    SegmentedButton<MealType>(
                        segments: const <ButtonSegment<MealType>>[
                          ButtonSegment<MealType>(value: MealType.morning, label: Text('Morning'), icon: Icon(Icons.wb_sunny_outlined)),
                          ButtonSegment<MealType>(value: MealType.night, label: Text('Night'), icon: Icon(Icons.nightlight_round_outlined)),
                        ],
                        selected: <MealType>{_selectedMealType},
                        onSelectionChanged: (Set<MealType> newSelection) {
                          setStateIfMounted(() { _selectedMealType = newSelection.first; });
                          _loadActiveStudentsAndInitializeAttendance();
                        },
                        style: SegmentedButton.styleFrom(selectedForegroundColor: Colors.white, selectedBackgroundColor: Colors.teal)),
                  ])))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Name or ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                isDense: true,
              ),
              onChanged: (value) {
                _searchTerm = value;
                _filterAndSortDisplayedStudents();
              },
            ),
          ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Switch(
                        value: _sortAbsenteesTop,
                        onChanged: (value) {
                          _sortAbsenteesTop = value;
                          _filterAndSortDisplayedStudents();
                        },
                      ),
                      Text("Show Absentees First"),
                    ],
                  ),
                  Text("Absent: $_absentCount / ${_displayedStudents.length}", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
          ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                ElevatedButton.icon(icon: Icon(Icons.done_all), label: Text('Mark All (Displayed) Present'), onPressed: () => _markAll(AttendanceStatus.present), style: ElevatedButton.styleFrom(backgroundColor: Colors.green[100], foregroundColor: Colors.green[800])),
                ElevatedButton.icon(icon: Icon(Icons.cancel_presentation_outlined), label: Text('Mark All (Displayed) Absent'), onPressed: () => _markAll(AttendanceStatus.absent), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100], foregroundColor: Colors.red[800])),
              ])),
          Expanded(
              child: _displayedStudents.isEmpty
                  ? Center(child: Text(_searchTerm.isNotEmpty ? 'No students found matching "$_searchTerm".' : 'No active students for the selected date.'))
                  : ListView.builder(
                  itemCount: _displayedStudents.length,
                  itemBuilder: (context, index) {
                    final student = _displayedStudents[index];
                    final currentStatus = _attendanceStatusMap[student.id] ?? AttendanceStatus.absent; // Default to absent visually
                    return Card(
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                                title: Text(student.name),
                                subtitle: Text("ID: ${student.id}"),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                                  ChoiceChip(
                                      label: Text('Present'), selected: currentStatus == AttendanceStatus.present,
                                      onSelected: (sel) { if (sel) setStateIfMounted(() {
                                        _attendanceStatusMap[student.id] = AttendanceStatus.present;
                                        _calculateAbsentCount(); // Recalculate on change
                                        if(_sortAbsenteesTop) _filterAndSortDisplayedStudents(); // Resort if needed
                                      }); },
                                      selectedColor: Colors.greenAccent[100], labelStyle: TextStyle(color: currentStatus == AttendanceStatus.present ? Colors.green[800] : Colors.black54)),
                                  SizedBox(width: 8),
                                  ChoiceChip(
                                      label: Text('Absent'), selected: currentStatus == AttendanceStatus.absent,
                                      onSelected: (sel) { if (sel) setStateIfMounted(() {
                                        _attendanceStatusMap[student.id] = AttendanceStatus.absent;
                                        _calculateAbsentCount(); // Recalculate on change
                                        if(_sortAbsenteesTop) _filterAndSortDisplayedStudents(); // Resort if needed
                                      }); },
                                      selectedColor: Colors.redAccent[100], labelStyle: TextStyle(color: currentStatus == AttendanceStatus.absent ? Colors.red[800] : Colors.black54)),
                                ]))));
                  })),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
                icon: Icon(Icons.save_alt_rounded), label: Text('Save All Attendance'),
                onPressed: _allActiveStudentsForDate.isNotEmpty ? _saveAttendance : null, // Enable based on if there are any active students at all
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: Size(double.infinity, 50), textStyle: TextStyle(fontSize: 18))),
          ),
        ],
      ),
    );
  }
}
