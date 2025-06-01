// lib/models/student_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { morning, night }
enum AttendanceStatus { present, absent }

class Student {
  String id;
  String name;
  String nameLowercase;
  DateTime messStartDate;
  DateTime originalServiceStartDate;
  bool currentCyclePaid;
  int compensatoryDays;
  List<AttendanceEntry> attendanceLog;
  List<PaymentHistoryEntry> paymentHistory;
  bool isArchived; // New field for archiving

  Student({
    required this.id,
    required this.name,
    required this.messStartDate,
    required this.originalServiceStartDate,
    this.currentCyclePaid = false,
    this.compensatoryDays = 0,
    List<AttendanceEntry>? attendanceLog,
    List<PaymentHistoryEntry>? paymentHistory,
    this.isArchived = false, // Default to not archived
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
      'originalServiceStartDate': Timestamp.fromDate(originalServiceStartDate),
      'currentCyclePaid': currentCyclePaid,
      'compensatoryDays': compensatoryDays,
      'attendanceLog': attendanceLog.map((e) => e.toMap()).toList(),
      'paymentHistory': paymentHistory.map((e) => e.toMap()).toList(),
      'isArchived': isArchived, // Add to map
    };
  }

  factory Student.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    DateTime osd = data['originalServiceStartDate'] != null
        ? (data['originalServiceStartDate'] as Timestamp).toDate()
        : (data['messStartDate'] as Timestamp).toDate();

    return Student(
      id: snapshot.id,
      name: data['name'] ?? '',
      messStartDate: (data['messStartDate'] as Timestamp).toDate(),
      originalServiceStartDate: osd,
      currentCyclePaid: data['currentCyclePaid'] ?? false,
      compensatoryDays: data['compensatoryDays'] ?? 0,
      attendanceLog: (data['attendanceLog'] as List<dynamic>? ?? [])
          .map((e) => AttendanceEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      paymentHistory: (data['paymentHistory'] as List<dynamic>? ?? [])
          .map((e) => PaymentHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      isArchived: data['isArchived'] ?? false, // Read from snapshot, default to false
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
