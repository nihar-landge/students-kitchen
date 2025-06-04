// lib/utils/payment_manager.dart
import 'package:intl/intl.dart';
import '../models/student_model.dart'; // Assuming Student, PaymentHistoryEntry are here

// MonthlyDueItem class definition
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

    // Determine the effective end for calculations. This limits how far we generate.
    DateTime overallCalculationCutoff = DateTime(upToDate.year, upToDate.month, DateTime(upToDate.year, upToDate.month + 1, 0).day);
    if (student.effectiveMessEndDate.isBefore(overallCalculationCutoff)) {
      overallCalculationCutoff = student.effectiveMessEndDate;
    }

    // If the student's service hasn't even started by originalServiceStartDate relative to overallCalculationCutoff, return empty.
    if (student.originalServiceStartDate.isAfter(overallCalculationCutoff)) {
      return billingPeriods;
    }

    DateTime currentCycleStartDateIterator = student.originalServiceStartDate;

    // Sanity check: student.messStartDate should not be before originalServiceStartDate.
    // This `actualMessStartDate` is the student's current designated service start.
    DateTime actualMessStartDate = student.messStartDate;
    if (actualMessStartDate.isBefore(student.originalServiceStartDate)) {
      actualMessStartDate = student.originalServiceStartDate;
    }

    int safetyBreak = 0; // To prevent potential infinite loops with complex date scenarios

    while ((currentCycleStartDateIterator.isBefore(student.effectiveMessEndDate) ||
        currentCycleStartDateIterator.isAtSameMomentAs(student.effectiveMessEndDate)) &&
        safetyBreak < 100) { // Added safetyBreak condition
      safetyBreak++;

      // If the start of the cycle we are about to generate is already past the overallCalculationCutoff, stop.
      if (currentCycleStartDateIterator.isAfter(overallCalculationCutoff)) {
        break;
      }

      DateTime periodActualStart = currentCycleStartDateIterator;
      DateTime periodActualEnd;

      // CASE 1: The current iteration point is before the student's designated current cycle start (actualMessStartDate)
      if (periodActualStart.isBefore(actualMessStartDate)) {
        // This is a historical cycle before the student's current `messStartDate`
        periodActualEnd = periodActualStart.add(Duration(days: 29)); // Standard 30-day historical cycle

        // If this historical cycle would overlap or cross into the `actualMessStartDate`,
        // truncate its end to be the day before `actualMessStartDate`.
        if (periodActualEnd.isAfter(actualMessStartDate.subtract(Duration(days: 1)))) {
          periodActualEnd = actualMessStartDate.subtract(Duration(days: 1));
        }
      }
      // CASE 2: The current iteration point is at or after actualMessStartDate.
      // This means we are at the student's current designated service period or a subsequent one.
      else {
        // Ensure periodActualStart aligns with actualMessStartDate if the iterator just jumped a gap to it.
        if (currentCycleStartDateIterator.isAtSameMomentAs(actualMessStartDate)) {
          periodActualStart = actualMessStartDate;
        }

        // Determine if this specific `periodActualStart` is the one defined by `actualMessStartDate`
        bool isTheDesignatedCurrentCycle = (periodActualStart.year == actualMessStartDate.year &&
            periodActualStart.month == actualMessStartDate.month &&
            periodActualStart.day == actualMessStartDate.day);

        if (isTheDesignatedCurrentCycle) {
          // This IS the cycle that starts on student.messStartDate (or actualMessStartDate)
          // Its end is the student's overall effectiveMessEndDate, which includes compensations.
          periodActualEnd = student.effectiveMessEndDate;
        } else {
          // This is a cycle that starts *after* student.messStartDate (actualMessStartDate),
          // so it should be a standard 30-day cycle, capped by the final student.effectiveMessEndDate.
          periodActualEnd = periodActualStart.add(Duration(days:29));
          if (periodActualEnd.isAfter(student.effectiveMessEndDate)) {
            periodActualEnd = student.effectiveMessEndDate;
          }
        }
      }

      // Final cap: periodActualEnd cannot go beyond the student's overall effectiveMessEndDate.
      if (periodActualEnd.isAfter(student.effectiveMessEndDate)) {
        periodActualEnd = student.effectiveMessEndDate;
      }

      // Validate if the calculated period is valid (start is not after end)
      if (periodActualStart.isAfter(periodActualEnd)) {
        // This can happen if date adjustments result in an invalid period.
        // Advance iterator to avoid getting stuck.
        currentCycleStartDateIterator = periodActualEnd.add(Duration(days: 1));
        // If after advancing, we are in a gap before actualMessStartDate, jump to actualMessStartDate
        if (currentCycleStartDateIterator.isBefore(actualMessStartDate) &&
            !currentCycleStartDateIterator.isAtSameMomentAs(actualMessStartDate)) {
          currentCycleStartDateIterator = actualMessStartDate;
        }
        continue; // Skip adding this invalid period
      }

      String displayLabel = "Cycle: ${DateFormat.MMMd().format(periodActualStart)} - ${DateFormat.MMMd().format(periodActualEnd)}";
      if (periodActualStart.year != periodActualEnd.year) {
        displayLabel = "Cycle: ${DateFormat.yMMMd().format(periodActualStart)} - ${DateFormat.yMMMd().format(periodActualEnd)}";
      }

      billingPeriods.add(MonthlyDueItem(
        monthYearDisplay: displayLabel,
        periodStartDate: periodActualStart,
        periodEndDate: periodActualEnd,
        feeDueForPeriod: standardMonthlyFee,
      ));

      // Prepare for the next iteration: move to the day after the current period ends.
      currentCycleStartDateIterator = periodActualEnd.add(Duration(days: 1));

      // CRUCIAL GAP JUMP:
      // If the next cycle's start date (`currentCycleStartDateIterator`) is now before
      // the student's designated current service start (`actualMessStartDate`),
      // it means we've processed all relevant historical cycles and the next "real" service
      // starts at `actualMessStartDate`. So, jump the iterator to `actualMessStartDate`.
      if (currentCycleStartDateIterator.isBefore(actualMessStartDate) &&
          !currentCycleStartDateIterator.isAtSameMomentAs(actualMessStartDate) ) { // Check not already on it
        currentCycleStartDateIterator = actualMessStartDate;
      }
    }

    // Final filter based on overallCalculationCutoff (mainly for display limiting)
    billingPeriods.removeWhere((bp) => bp.periodStartDate.isAfter(overallCalculationCutoff));

    // Payment allocation logic (remains largely the same)
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
    return billingPeriods;
  }
}
