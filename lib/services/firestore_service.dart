// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart'; // Import AppSettings model

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _studentsCollection = 'students';
  final String _settingsCollection = 'settings'; // For app settings

  // --- App Settings Methods ---
  Stream<AppSettings> getAppSettingsStream() {
    return _db
        .collection(_settingsCollection)
        .doc(APP_SETTINGS_DOC_ID) // Use fixed document ID
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return AppSettings.fromSnapshot(snapshot);
      }
      // Return default settings if document doesn't exist
      return AppSettings(standardMonthlyFee: 2000.0); // Default fee
    });
  }

  Future<void> updateStandardMonthlyFee(double newFee) {
    return _db
        .collection(_settingsCollection)
        .doc(APP_SETTINGS_DOC_ID)
        .set({'standardMonthlyFee': newFee}, SetOptions(merge: true)); // Use set with merge to create if not exists or update
  }

  // --- Student Methods (Existing methods remain the same) ---
  Stream<List<Student>> getStudentsStream({String? nameSearchTerm}) {
    Query query = _db.collection(_studentsCollection);

    if (nameSearchTerm != null && nameSearchTerm.isNotEmpty) {
      String lowerSearchTerm = nameSearchTerm.toLowerCase();
      query = query
          .where('name_lowercase', isGreaterThanOrEqualTo: lowerSearchTerm)
          .where('name_lowercase', isLessThanOrEqualTo: lowerSearchTerm + '\uf8ff')
          .orderBy('name_lowercase');
    } else {
      query = query.orderBy('name');
    }

    return query.snapshots().map((snapshot) {
      try {
        return snapshot.docs.map((doc) => Student.fromSnapshot(doc)).toList();
      } catch (e) {
        print("Error mapping students in FirestoreService: $e");
        return [];
      }
    });
  }

  Stream<Student?> getStudentStream(String studentId) {
    return _db.collection(_studentsCollection).doc(studentId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        try {
          return Student.fromSnapshot(snapshot);
        } catch (e) {
          print("Error mapping student $studentId in FirestoreService: $e");
          return null;
        }
      }
      return null;
    });
  }

  Future<bool> studentExists(String studentId) async {
    final doc = await _db.collection(_studentsCollection).doc(studentId).get();
    return doc.exists;
  }

  Future<void> addStudent(Student student) {
    return _db.collection(_studentsCollection).doc(student.id).set(student.toMap());
  }

  Future<void> updateStudent(String studentId, Student student) {
    Map<String, dynamic> studentData = student.toMap();
    return _db.collection(_studentsCollection).doc(studentId).update(studentData);
  }

  Future<void> updateStudentPartial(String studentId, Map<String, dynamic> data) {
    if (data.containsKey('name') && data['name'] is String) {
      data['name_lowercase'] = (data['name'] as String).toLowerCase();
    }
    if (data.containsKey('messStartDate') && data['messStartDate'] is DateTime) {
      data['messStartDate'] = Timestamp.fromDate(data['messStartDate'] as DateTime);
    }
    if (data.containsKey('attendanceLog') && data['attendanceLog'] is List) {
      data['attendanceLog'] = (data['attendanceLog'] as List<dynamic>).map((e) {
        if (e is AttendanceEntry) return e.toMap();
        if (e is Map<String,dynamic>) return e;
        return {};
      }).toList();
    }
    if (data.containsKey('paymentHistory') && data['paymentHistory'] is List) {
      data['paymentHistory'] = (data['paymentHistory'] as List<dynamic>).map((e) {
        if (e is PaymentHistoryEntry) return e.toMap();
        if (e is Map<String,dynamic>) return e;
        return {};
      }).toList();
    }
    return _db.collection(_studentsCollection).doc(studentId).update(data);
  }

  Future<void> deleteStudent(String studentId) {
    return _db.collection(_studentsCollection).doc(studentId).delete();
  }
}
