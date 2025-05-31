// lib/models/student_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { morning, night }
enum AttendanceStatus { present, absent }

class Student {
  String id;
  String name;
  String nameLowercase;
  DateTime messStartDate; // Start of the current/active service window
  DateTime originalServiceStartDate; // The very first day service began, immutable after creation
  bool currentCyclePaid; // General flag, true if all historical dues are cleared
  int compensatoryDays;
  List<AttendanceEntry> attendanceLog;
  List<PaymentHistoryEntry> paymentHistory;

  Student({
    required this.id,
    required this.name,
    required this.messStartDate,
    required this.originalServiceStartDate, // Added
    this.currentCyclePaid = false,
    this.compensatoryDays = 0,
    List<AttendanceEntry>? attendanceLog,
    List<PaymentHistoryEntry>? paymentHistory,
  })  : this.nameLowercase = name.toLowerCase(),
        this.attendanceLog = attendanceLog ?? [],
        this.paymentHistory = paymentHistory ?? [];

  String get contactNumber => id;
  // effectiveMessEndDate is based on the current messStartDate and compensatory days
  DateTime get baseEndDate => messStartDate.add(Duration(days: 30));
  DateTime get effectiveMessEndDate => baseEndDate.add(Duration(days: compensatoryDays));

  int get daysRemaining { // Days remaining in the current nominal 30-day cycle
    final now = DateTime.now();
    final difference = effectiveMessEndDate.difference(now);
    return difference.isNegative ? 0 : difference.inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'name_lowercase': nameLowercase,
      'messStartDate': Timestamp.fromDate(messStartDate),
      'originalServiceStartDate': Timestamp.fromDate(originalServiceStartDate), // Added
      'currentCyclePaid': currentCyclePaid,
      'compensatoryDays': compensatoryDays,
      'attendanceLog': attendanceLog.map((e) => e.toMap()).toList(),
      'paymentHistory': paymentHistory.map((e) => e.toMap()).toList(),
    };
  }

  factory Student.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    // Provide a default for originalServiceStartDate if it's missing in older documents,
    // ideally defaulting to messStartDate for those older records.
    DateTime osd = data['originalServiceStartDate'] != null
        ? (data['originalServiceStartDate'] as Timestamp).toDate()
        : (data['messStartDate'] as Timestamp).toDate(); // Fallback for old data

    return Student(
      id: snapshot.id,
      name: data['name'] ?? '',
      messStartDate: (data['messStartDate'] as Timestamp).toDate(),
      originalServiceStartDate: osd, // Added
      currentCyclePaid: data['currentCyclePaid'] ?? false,
      compensatoryDays: data['compensatoryDays'] ?? 0,
      attendanceLog: (data['attendanceLog'] as List<dynamic>? ?? [])
          .map((e) => AttendanceEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      paymentHistory: (data['paymentHistory'] as List<dynamic>? ?? [])
          .map((e) => PaymentHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// AttendanceEntry and PaymentHistoryEntry classes remain the same as in mess_app_student_model_dart_v2
// ... (copy AttendanceEntry and PaymentHistoryEntry class definitions here) ...
class AttendanceEntry {
  DateTime date;
  MealType mealType;
  AttendanceStatus status;

  AttendanceEntry({
    required this.date,
    required this.mealType,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'mealType': mealType.toString(),
      'status': status.toString(),
    };
  }

  factory AttendanceEntry.fromMap(Map<String, dynamic> map) {
    return AttendanceEntry(
      date: (map['date'] as Timestamp).toDate(),
      mealType: MealType.values.firstWhere((e) => e.toString() == map['mealType'], orElse: () => MealType.morning),
      status: AttendanceStatus.values.firstWhere((e) => e.toString() == map['status'], orElse: () => AttendanceStatus.absent),
    );
  }
}

class PaymentHistoryEntry {
  DateTime paymentDate;
  DateTime cycleStartDate; // Start of the specific billing period this payment is for
  DateTime cycleEndDate;   // End of the specific billing period this payment is for
  bool paid; // Indicates this entry is a valid payment, not a 'due' record
  double amountPaid;

  PaymentHistoryEntry({
    required this.paymentDate,
    required this.cycleStartDate,
    required this.cycleEndDate,
    required this.paid,
    required this.amountPaid,
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentDate': Timestamp.fromDate(paymentDate),
      'cycleStartDate': Timestamp.fromDate(cycleStartDate),
      'cycleEndDate': Timestamp.fromDate(cycleEndDate),
      'paid': paid,
      'amountPaid': amountPaid,
    };
  }

  factory PaymentHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PaymentHistoryEntry(
      paymentDate: (map['paymentDate'] as Timestamp).toDate(),
      cycleStartDate: (map['cycleStartDate'] as Timestamp).toDate(),
      cycleEndDate: (map['cycleEndDate'] as Timestamp).toDate(),
      paid: map['paid'] ?? false, // Should default to true if it's a payment
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
