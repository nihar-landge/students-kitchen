// lib/screens/payments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

class PaymentsScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final Function(Student) onViewStudent;

  PaymentsScreen({required this.firestoreService, required this.onViewStudent});

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _filterOption = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Status Overview'),
        actions: [
          PopupMenuButton<String>(
              icon: Icon(Icons.filter_list),
              onSelected: (v) => setState(() => _filterOption = v),
              itemBuilder: (ctx) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'All', child: Text('Show All')),
                const PopupMenuItem<String>(value: 'Paid', child: Text('Show Paid Only')),
                const PopupMenuItem<String>(value: 'Unpaid', child: Text('Show Unpaid Only')),
              ])
        ],
      ),
      body: StreamBuilder<List<Student>>(
        stream: widget.firestoreService.getStudentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          List<Student> allStudents = snapshot.data ?? [];
          List<Student> filteredStudents = List.from(allStudents);

          if (_filterOption == 'Paid') {
            filteredStudents = allStudents.where((s) => s.currentCyclePaid).toList();
          } else if (_filterOption == 'Unpaid') {
            filteredStudents = allStudents.where((s) => !s.currentCyclePaid).toList();
          }
          filteredStudents.sort((a, b) => a.effectiveMessEndDate.compareTo(b.effectiveMessEndDate));

          return Column(
            children: [
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Chip(label: Text('Filter: $_filterOption Students (${filteredStudents.length})'), avatar: Icon(Icons.info_outline))),
              Expanded(
                child: filteredStudents.isEmpty
                    ? Center(child: Text('No students match the filter "$_filterOption".'))
                    : ListView.builder(
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      bool isOverdue = student.effectiveMessEndDate.isBefore(DateTime.now()) && !student.currentCyclePaid;
                      return Card(
                          color: isOverdue ? Colors.red.shade50 : null,
                          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                              leading: Icon(student.currentCyclePaid ? Icons.check_circle_outline : Icons.highlight_off_outlined, color: student.currentCyclePaid ? Colors.green : (isOverdue ? Colors.red.shade700 : Colors.orange), size: 30),
                              title: Text(student.name, style: TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('Contact: ${student.contactNumber}\nEnds: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}\nStatus: ${student.currentCyclePaid ? "Paid" : (isOverdue ? "OVERDUE" : "Not Paid")}'),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              isThreeLine: true,
                              onTap: () => widget.onViewStudent(student)));
                    }),
              ),
            ],
          );
        },
      ),
    );
  }
}
