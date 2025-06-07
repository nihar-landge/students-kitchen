// lib/utils/payment_manager.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';

class MonthlyDueItem {
  final String monthYearDisplay;
  final DateTime periodStartDate;
  final DateTime periodEndDate;
  final double feeDueForPeriod;
  double amountPaidForPeriod;
  String status;

  MonthlyDueItem({
    required this.monthYearDisplay,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.feeDueForPeriod,
    this.amountPaidForPeriod = 0.0,
  }) : status = (amountPaidForPeriod >= feeDueForPeriod)
      ? "Paid"
      : (amountPaidForPeriod > 0 ? "Partially Paid" : "Unpaid");

  double get remainingForPeriod {
    double remaining = feeDueForPeriod - amountPaidForPeriod;
    return (remaining < 0) ? 0 : remaining;
  }

  void updateStatus() {
    status = (amountPaidForPeriod >= feeDueForPeriod)
        ? "Paid"
        : (amountPaidForPeriod > 0 ? "Partially Paid" : "Unpaid");
  }
}

class PaymentManager {
  // FINAL CORRECTED VERSION: Reads from the new serviceHistory list for 100% accuracy.
  static List<MonthlyDueItem> calculateBillingPeriodsWithPaymentAllocation(
      Student student, AppSettings appSettings, DateTime upToDate) {
    List<MonthlyDueItem> billingPeriods = [];

    // If there is no service history, we can't generate bills.
    if (student.serviceHistory.isEmpty) {
      return billingPeriods;
    }

    // --- REVISED LOGIC ---
    // Each entry in the serviceHistory is now treated as a SINGLE billing cycle.
    for (var period in student.serviceHistory) {
      DateTime serviceStartDate = (period['startDate'] as Timestamp).toDate();
      DateTime serviceEndDate = (period['endDate'] as Timestamp).toDate();

      // The entire period is ONE billing cycle. Do not break it into 30-day chunks.
      billingPeriods.add(_createDueItem(serviceStartDate, serviceEndDate, appSettings));
    }

    _allocatePayments(student, billingPeriods);

    return billingPeriods;
  }

  static MonthlyDueItem _createDueItem(DateTime startDate, DateTime endDate, AppSettings appSettings) {
    final double feeForThisPeriod = appSettings.getFeeForDate(startDate);
    String displayLabel = "Cycle: ${DateFormat.MMMd().format(startDate)} - ${DateFormat.MMMd().format(endDate)}";
    if (startDate.year != endDate.year) {
      displayLabel = "Cycle: ${DateFormat.yMMMd().format(startDate)} - ${DateFormat.yMMMd().format(endDate)}";
    }
    return MonthlyDueItem(
      monthYearDisplay: displayLabel,
      periodStartDate: startDate,
      periodEndDate: endDate,
      feeDueForPeriod: feeForThisPeriod,
    );
  }

  // The _allocatePayments function remains unchanged.
  static void _allocatePayments(Student student, List<MonthlyDueItem> billingPeriods) {
    List<PaymentHistoryEntry> sortedPayments = List.from(student.paymentHistory);
    sortedPayments.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    for (var payment in sortedPayments) {
      if (!payment.paid) continue;
      double paymentAmountToAllocate = payment.amountPaid;

      MonthlyDueItem? specificPeriodDueItem = billingPeriods.firstWhere(
              (due) => due.periodStartDate.isAtSameMomentAs(payment.cycleStartDate) && due.periodEndDate.isAtSameMomentAs(payment.cycleEndDate),
          orElse: () => MonthlyDueItem(monthYearDisplay: "Error_NotFound", periodStartDate: DateTime(0), periodEndDate: DateTime(0), feeDueForPeriod: 0)
      );

      if (specificPeriodDueItem.periodStartDate.year != 0 && specificPeriodDueItem.status != "Paid") {
        double canPayForThisPeriod = specificPeriodDueItem.feeDueForPeriod - specificPeriodDueItem.amountPaidForPeriod;
        double paidNow = (paymentAmountToAllocate >= canPayForThisPeriod) ? canPayForThisPeriod : paymentAmountToAllocate;

        specificPeriodDueItem.amountPaidForPeriod += paidNow;
        specificPeriodDueItem.updateStatus();
        paymentAmountToAllocate -= paidNow;
      }

      if(paymentAmountToAllocate > 0) {
        for (var dueItem in billingPeriods) {
          if (paymentAmountToAllocate <= 0) break;
          if (dueItem.status != "Paid") {
            double canPayForThisPeriod = dueItem.feeDueForPeriod - dueItem.amountPaidForPeriod;
            double paidNow = (paymentAmountToAllocate >= canPayForThisPeriod) ? canPayForThisPeriod : paymentAmountToAllocate;

            dueItem.amountPaidForPeriod += paidNow;
            dueItem.updateStatus();
            paymentAmountToAllocate -= paidNow;
          }
        }
      }
    }
  }
}