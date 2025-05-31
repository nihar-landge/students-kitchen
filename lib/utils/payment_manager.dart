// lib/utils/payment_manager.dart
import 'package:intl/intl.dart';
import '../models/student_model.dart'; // Assuming Student, PaymentHistoryEntry are here

// MonthlyDueItem class definition (Simplified)
class MonthlyDueItem {
  final String monthYearDisplay;
  final DateTime periodStartDate;
  final DateTime periodEndDate;
  final double feeDueForPeriod; // Standard fee for this period
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
    return (remaining < 0) ? 0 : remaining; // Ensure not negative
  }

  void updateStatus() {
    status = (amountPaidForPeriod >= feeDueForPeriod)
        ? "Paid"
        : (amountPaidForPeriod > 0 ? "Partially Paid" : "Unpaid");
  }
}

class PaymentManager {
  static List<MonthlyDueItem> calculateBillingPeriodsWithPaymentAllocation(
      Student student, double standardMonthlyFee, DateTime upToDate) {
    List<MonthlyDueItem> billingPeriods = [];
    if (student.originalServiceStartDate.isAfter(upToDate) &&
        !(student.originalServiceStartDate.year == upToDate.year && student.originalServiceStartDate.month == upToDate.month)) {
      return billingPeriods;
    }

    DateTime periodIteratorStart = student.originalServiceStartDate;
    DateTime calculationRangeEnd = DateTime(upToDate.year, upToDate.month, DateTime(upToDate.year, upToDate.month + 1, 0).day);
    if(student.effectiveMessEndDate.isBefore(calculationRangeEnd)){
      calculationRangeEnd = student.effectiveMessEndDate;
    }

    int periodIndex = 0;
    DateTime currentMonthEffectiveStart = student.originalServiceStartDate;

    while(currentMonthEffectiveStart.isBefore(calculationRangeEnd) || currentMonthEffectiveStart.isAtSameMomentAs(calculationRangeEnd)) {
      DateTime currentPeriodBillingStart;
      DateTime currentPeriodBillingEnd;
      String displaySuffix = "";

      if (periodIndex == 0) {
        currentPeriodBillingStart = student.originalServiceStartDate;
        if (student.originalServiceStartDate.day != 1) {
          displaySuffix = " (from ${DateFormat.d().format(currentPeriodBillingStart)})";
        }
      } else {
        currentPeriodBillingStart = DateTime(currentMonthEffectiveStart.year, currentMonthEffectiveStart.month, 1);
      }
      currentPeriodBillingEnd = DateTime(currentPeriodBillingStart.year, currentPeriodBillingStart.month + 1, 0);

      if (currentPeriodBillingEnd.isAfter(student.effectiveMessEndDate)) {
        currentPeriodBillingEnd = student.effectiveMessEndDate;
      }

      if (!currentPeriodBillingStart.isAfter(currentPeriodBillingEnd)) {
        billingPeriods.add(MonthlyDueItem(
          monthYearDisplay: DateFormat('MMMM yyyy').format(currentPeriodBillingStart) + displaySuffix,
          periodStartDate: currentPeriodBillingStart,
          periodEndDate: currentPeriodBillingEnd,
          feeDueForPeriod: standardMonthlyFee,
        ));
      }

      if (currentPeriodBillingEnd.isAtSameMomentAs(student.effectiveMessEndDate)) break;

      if (currentMonthEffectiveStart.month == 12) {
        currentMonthEffectiveStart = DateTime(currentMonthEffectiveStart.year + 1, 1, 1);
      } else {
        currentMonthEffectiveStart = DateTime(currentMonthEffectiveStart.year, currentMonthEffectiveStart.month + 1, 1);
      }
      periodIndex++;
      if (currentMonthEffectiveStart.isAfter(student.effectiveMessEndDate) && billingPeriods.isNotEmpty && billingPeriods.last.periodEndDate.isAtSameMomentAs(student.effectiveMessEndDate)) break;
    }

    // Allocate payments
    List<PaymentHistoryEntry> sortedPayments = List.from(student.paymentHistory);
    sortedPayments.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));

    for (var payment in sortedPayments) {
      if (!payment.paid) continue;
      double paymentAmountToAllocate = payment.amountPaid;

      // Try to allocate to the specific period the payment was recorded for
      MonthlyDueItem? specificPeriodDueItem = billingPeriods.firstWhere(
              (due) => due.periodStartDate.isAtSameMomentAs(payment.cycleStartDate),
          orElse: () => MonthlyDueItem(monthYearDisplay: "Error", periodStartDate: DateTime(0), periodEndDate: DateTime(0), feeDueForPeriod: 0)
      );

      if (specificPeriodDueItem.periodStartDate.year != 0 && specificPeriodDueItem.status != "Paid") {
        double canPayForThisPeriod = specificPeriodDueItem.feeDueForPeriod - specificPeriodDueItem.amountPaidForPeriod;
        double paidNow = (paymentAmountToAllocate >= canPayForThisPeriod) ? canPayForThisPeriod : paymentAmountToAllocate;

        specificPeriodDueItem.amountPaidForPeriod += paidNow;
        specificPeriodDueItem.updateStatus();
        paymentAmountToAllocate -= paidNow;
      }

      // Allocate any remaining payment amount to the oldest unpaid/partially paid periods (FIFO for leftovers)
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
    // Removed the second pass that explicitly set carriedForwardDue.
    // Each MonthlyDueItem now stands on its own regarding its fee and payments against it.
    return billingPeriods;
  }
}
