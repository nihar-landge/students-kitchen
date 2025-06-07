// lib/models/student_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { morning, night }
enum AttendanceStatus { present, absent }

class Student {
  String id;
  String name;
  String nameLowercase;
  List<AttendanceEntry> attendanceLog;
  List<PaymentHistoryEntry> paymentHistory;
  bool isArchived;

  // --- DATA MODEL CHANGE ---
  // These fields are now replaced by serviceHistory for more robust calculations.
  // We will keep them for now for backwards compatibility but new logic will use serviceHistory.
  DateTime messStartDate;
  DateTime originalServiceStartDate;
  int compensatoryDays;

  // NEW: This list will store all active service periods. This is the key to the fix.
  // Each map will be like: { 'startDate': Timestamp, 'endDate': Timestamp }
  List<Map<String, dynamic>> serviceHistory;

  Student({
    required this.id,
    required this.name,
    required this.messStartDate,
    required this.originalServiceStartDate,
    this.compensatoryDays = 0,
    List<AttendanceEntry>? attendanceLog,
    List<PaymentHistoryEntry>? paymentHistory,
    List<Map<String, dynamic>>? serviceHistory, // Add to constructor
    this.isArchived = false,
  })  : nameLowercase = name.toLowerCase(),
        attendanceLog = attendanceLog ?? [],
        paymentHistory = paymentHistory ?? [],
        serviceHistory = serviceHistory ?? []; // Initialize new list

  String get contactNumber => id;

  // This getter now intelligently finds the LATEST service end date from the history.
  DateTime get effectiveMessEndDate {
    if (serviceHistory.isEmpty) {
      // Fallback for old data: use the old calculation method
      return messStartDate.add(Duration(days: 30 + compensatoryDays));
    }
    // Get the end date from the last service period in the history
    final lastPeriod = serviceHistory.last;
    return (lastPeriod['endDate'] as Timestamp).toDate();
  }

  // This getter is for display purposes only.
  bool get currentCyclePaid {
    // This logic would need to be updated to check against the new payment manager result.
    // For now, we can simplify or accept this might be less accurate until a full refactor.
    return false; // Placeholder
  }


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
      'compensatoryDays': compensatoryDays,
      'attendanceLog': attendanceLog.map((e) => e.toMap()).toList(),
      'paymentHistory': paymentHistory.map((e) => e.toMap()).toList(),
      'isArchived': isArchived,
      // Add the new field to the map
      'serviceHistory': serviceHistory,
    };
  }

  factory Student.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    // Read the new service history list from Firestore
    final serviceHistoryData = (data['serviceHistory'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    return Student(
      id: snapshot.id,
      name: data['name'] ?? '',
      messStartDate: (data['messStartDate'] as Timestamp).toDate(),
      originalServiceStartDate: (data['originalServiceStartDate'] as Timestamp).toDate(),
      compensatoryDays: data['compensatoryDays'] ?? 0,
      attendanceLog: (data['attendanceLog'] as List<dynamic>? ?? [])
          .map((e) => AttendanceEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      paymentHistory: (data['paymentHistory'] as List<dynamic>? ?? [])
          .map((e) => PaymentHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      isArchived: data['isArchived'] ?? false,
      serviceHistory: serviceHistoryData,
    );
  }
}

// AttendanceEntry and PaymentHistoryEntry classes remain unchanged.
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