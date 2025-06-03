// lib/screens/archived_students_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'student_detail_screen.dart'; // To navigate to student details

class ArchivedStudentsScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final UserRole userRole; // Pass user role for StudentDetailScreen

  const ArchivedStudentsScreen({ // Add const
    super.key, // Use super.key
    required this.firestoreService,
    required this.userRole,
  });

  @override
  ArchivedStudentsScreenState createState() => ArchivedStudentsScreenState();
}

class ArchivedStudentsScreenState extends State<ArchivedStudentsScreen> {
  String _searchTerm = '';

  void _navigateToStudentDetail(BuildContext navContext, Student student) {
    Navigator.push(
      navContext,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          studentId: student.id,
          firestoreService: widget.firestoreService,
          userRole: widget.userRole, // Pass role to detail screen
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Archived Students')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Archived Students by Name...',
                hintText: 'Enter name...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchTerm = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Student>>(
              stream: widget.firestoreService.getStudentsStream(
                nameSearchTerm: _searchTerm.isNotEmpty ? _searchTerm : null,
                archiveStatusFilter: StudentArchiveStatusFilter.archived, // Fetch only archived
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final archivedStudents = snapshot.data ?? [];

                if (archivedStudents.isEmpty) {
                  return Center(
                    child: Text(_searchTerm.isNotEmpty
                        ? 'No archived students found matching "$_searchTerm".'
                        : 'No students have been archived yet.'),
                  );
                }

                return ListView.builder(
                  itemCount: archivedStudents.length,
                  itemBuilder: (context, index) {
                    final student = archivedStudents[index];
                    return Card(
                      color: Colors.grey[200], // Slightly different background for archived items
                      child: ListTile(
                        leading: Icon(Icons.archive_outlined, color: Colors.grey[700]),
                        title: Hero(
                          // Using a different tag prefix for archived students if needed, or ensure uniqueness
                          tag: 'archived_student_name_${student.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(student.name, style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                        ),
                        subtitle: Text(
                            'Contact: ${student.contactNumber}\nArchived (Service Ended: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)})'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        isThreeLine: true,
                        onTap: () => _navigateToStudentDetail(context, student),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
