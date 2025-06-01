// lib/screens/students_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/user_model.dart'; // Import UserRole
import '../services/firestore_service.dart';
// Ensure there is NO 'import 'dashboard_screen.dart';' here unless absolutely necessary

class StudentsScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final UserRole userRole;
  final VoidCallback onAddStudent;
  final Function(Student) onViewStudent;

  StudentsScreen({
    required this.firestoreService,
    required this.userRole,
    required this.onAddStudent,
    required this.onViewStudent,
    Key? key, // Added Key
  }) : super(key: key);

  @override
  _StudentsScreenState createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Students List')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Students by Name (starts with)...',
                hintText: 'Enter name...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() { _searchTerm = value; });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Student>>(
              stream: widget.firestoreService.getStudentsStream(nameSearchTerm: _searchTerm.isNotEmpty ? _searchTerm : null),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());

                final studentsToDisplay = snapshot.data ?? [];

                if (studentsToDisplay.isEmpty) {
                  return Center(child: Text(_searchTerm.isNotEmpty ? 'No students found matching "$_searchTerm".' : 'No students added yet.'));
                }

                return ListView.builder(
                  itemCount: studentsToDisplay.length,
                  itemBuilder: (context, index) {
                    final student = studentsToDisplay[index];
                    bool displayPaidStatusIcon = widget.userRole == UserRole.owner;

                    return Card(
                      child: ListTile(
                        leading: displayPaidStatusIcon ? CircleAvatar(
                          backgroundColor: student.currentCyclePaid
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                              : Theme.of(context).colorScheme.error.withOpacity(0.2),
                          child: Icon(
                              student.currentCyclePaid ? Icons.check : Icons.close,
                              color: student.currentCyclePaid
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error
                          ),
                        ) : Icon(Icons.person_pin_circle_outlined, color: Theme.of(context).colorScheme.primary), // Generic icon for guest
                        title: Hero(
                          tag: 'student_name_${student.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(student.name, style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                        ),
                        subtitle: Text('Contact: ${student.contactNumber}\nEnds: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)} (Rem: ${student.daysRemaining} days)'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        isThreeLine: true,
                        onTap: () => widget.onViewStudent(student),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.userRole == UserRole.owner
          ? FloatingActionButton.extended(
        onPressed: widget.onAddStudent,
        icon: Icon(Icons.add), label: Text('Add Student'),
      )
          : null,
    );
  }
}
