// lib/models/student_model.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp and DocumentSnapshot

// Enums defined here are accessible within this file and where this file is imported.
enum MealType { morning, night }
enum AttendanceStatus { present, absent }

class Student {
  String id;
  String name;
  String nameLowercase;
  DateTime messStartDate;
  bool currentCyclePaid;
  int compensatoryDays;
  List<AttendanceEntry> attendanceLog;
  List<PaymentHistoryEntry> paymentHistory;

  Student({
    required this.id,
    required this.name,
    required this.messStartDate,
    this.currentCyclePaid = false,
    this.compensatoryDays = 0,
    List<AttendanceEntry>? attendanceLog,
    List<PaymentHistoryEntry>? paymentHistory,
  })  : this.nameLowercase = name.toLowerCase(),
        this.attendanceLog = attendanceLog ?? [],
        this.paymentHistory = paymentHistory ?? [];

  String get contactNumber => id;
  DateTime get baseEndDate => messStartDate.add(Duration(days: 30));
  DateTime get effectiveMessEndDate => baseEndDate.add(Duration(days: compensatoryDays));
  int get daysRemaining {
    final now = DateTime.now();
    final difference = effectiveMessEndDate.difference(now);
    return difference.isNegative ? 0 : difference.inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'name_lowercase': nameLowercase,
      'messStartDate': Timestamp.fromDate(messStartDate),
      'currentCyclePaid': currentCyclePaid,
      'compensatoryDays': compensatoryDays,
      'attendanceLog': attendanceLog.map((e) => e.toMap()).toList(),
      'paymentHistory': paymentHistory.map((e) => e.toMap()).toList(),
    };
  }

  factory Student.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Student(
      id: snapshot.id,
      name: data['name'] ?? '',
      messStartDate: (data['messStartDate'] as Timestamp).toDate(),
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
      'mealType': mealType.toString(), // Store enum as string
      'status': status.toString(),   // Store enum as string
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
  DateTime cycleStartDate;
  DateTime cycleEndDate;
  bool paid;
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
      paid: map['paid'] ?? false,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
