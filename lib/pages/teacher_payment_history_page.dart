// 📁 lib/pages/teacher_payment_history_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import 'payment_details_page.dart';
import 'dart:developer';

class TeacherPaymentHistoryPage extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final Function(String teacherId, String teacherName) onPayRemainingBalance;

  const TeacherPaymentHistoryPage({
    Key? key,
    required this.teacherId,
    required this.teacherName,
    required this.onPayRemainingBalance,
  }) : super(key: key);

  @override
  State<TeacherPaymentHistoryPage> createState() =>
      _TeacherPaymentHistoryPageState();
}

class _TeacherPaymentHistoryPageState extends State<TeacherPaymentHistoryPage> {
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _isProcessing = false;

  // Static method to delete a payment from Firestore
  static void _deletePayment(String paymentId, String teacherId,
      ScaffoldMessengerState? messenger) async {
    try {
      log('DEBUG: Attempting to delete payment with ID: $paymentId');
      final teacherDocRef =
          FirebaseFirestore.instance.collection('teachers').doc(teacherId);
      final paymentDocRef = FirebaseFirestore.instance
          .collection('teacher_payments')
          .doc(paymentId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final paymentToDeleteDoc = await transaction.get(paymentDocRef);
        if (!paymentToDeleteDoc.exists) {
          throw Exception("Payment document not found");
        }
        final paymentToDeleteData =
            paymentToDeleteDoc.data() as Map<String, dynamic>;

        final teacherDoc = await transaction.get(teacherDocRef);
        if (!teacherDoc.exists) {
          throw Exception("Teacher document not found");
        }

        // Get all payments to find the one immediately before the deleted one
        final paymentsQuery = await FirebaseFirestore.instance
            .collection('teacher_payments')
            .where('teacherId', isEqualTo: teacherId)
            .orderBy('paymentDate', descending: true)
            .get();

        double newRemainingBalance = 0.0;
        DateTime newLastPaymentDate = DateTime(2000);

        // Find the index of the payment to be deleted
        final payments = paymentsQuery.docs;
        final deletedPaymentIndex =
            payments.indexWhere((doc) => doc.id == paymentId);

        if (deletedPaymentIndex != -1) {
          // Check if there is a payment before the one being deleted
          if (deletedPaymentIndex + 1 < payments.length) {
            final previousPayment = payments[deletedPaymentIndex + 1];
            final previousPaymentData =
                previousPayment.data() as Map<String, dynamic>;

            // The new remaining balance is the balance after the previous payment
            newRemainingBalance =
                (previousPaymentData['remainingBalance'] as num?)?.toDouble() ??
                    0.0;
            // The new last payment date is the date of the previous payment
            newLastPaymentDate =
                (previousPaymentData['paymentDate'] as Timestamp).toDate();
          }
          // If deletedPaymentIndex is 0 and there are no other payments,
          // the balance should be reset to 0, which is our default value.
        } else {
          // Should not happen, but as a fallback
          throw Exception("Payment to delete not found in query results.");
        }

        // Update the teacher's document
        transaction.update(teacherDocRef, {
          'remainingBalance': newRemainingBalance,
          'lastPaymentDate': Timestamp.fromDate(newLastPaymentDate),
        });

        // Delete the payment document
        transaction.delete(paymentDocRef);
      });

      log('DEBUG: Transaction committed. Payment $paymentId deleted.');
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Payment deleted successfully!'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      log('DEBUG: Failed to delete payment: $e');
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Failed to delete payment: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // New function to calculate earnings and breakdown
  Future<Map<String, dynamic>> _calculateEarnings(
      String teacherId, DateTime lastPaymentDate) async {
    print(
        'DEBUG: Calculating earnings for teacher $teacherId since $lastPaymentDate');
    final earningsBreakdown = <String, Map<String, dynamic>>{};
    double totalCalculatedEarnings = 0.0;
    final studentsPaidFor = <Map<String, dynamic>>[];
    final teacherDoc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .get();
    final groupIds = List<String>.from(teacherDoc.data()?['groupIds'] ?? []);
    final percentage =
        (teacherDoc.data()?['percentage'] as num?)?.toDouble() ?? 0.0;

    if (groupIds.isEmpty) {
      return {
        'calculatedEarnings': 0.0,
        'earningsBreakdown': [],
        'studentsPaidFor': [],
      };
    }

    final attendanceQuery = FirebaseFirestore.instance
        .collection('attendance')
        .where('teacherId', isEqualTo: teacherId)
        .where('date', isGreaterThan: Timestamp.fromDate(lastPaymentDate));

    final attendanceSnapshots = await attendanceQuery.get();
    print(
        'DEBUG: Found ${attendanceSnapshots.docs.length} attendance records.');

    for (var doc in attendanceSnapshots.docs) {
      final data = doc.data();
      final studentId = data['studentId'] as String;
      final date = data['date'] as Timestamp;
      final groupId = data['groupId'] as String;
      final groupName = data['groupName'] as String? ?? 'N/A';
      final pricePerStudent =
          (data['paymentPerStudent'] as num?)?.toDouble() ?? 0.0;
      final calculatedAmount = pricePerStudent * (percentage / 100);

      // Add to total earnings
      totalCalculatedEarnings += calculatedAmount;

      // Add student to the list of students paid for with date
      studentsPaidFor
          .add({'studentId': studentId, 'date': date, 'groupId': groupId});

      // Update earnings breakdown by group
      if (!earningsBreakdown.containsKey(groupId)) {
        earningsBreakdown[groupId] = {
          'groupId': groupId,
          'groupName': groupName,
          'presentStudents': 0,
          'earnings': 0.0,
        };
      }
      earningsBreakdown[groupId]!['presentStudents'] += 1;
      earningsBreakdown[groupId]!['earnings'] += calculatedAmount;
    }

    log('DEBUG: Calculated earnings breakdown: $earningsBreakdown');
    return {
      'calculatedEarnings': totalCalculatedEarnings,
      'earningsBreakdown': earningsBreakdown.values.toList(),
      'studentsPaidFor': studentsPaidFor,
    };
  }

  // New method to process the payment and update Firestore
  Future<void> _processPayment(
      String teacherId,
      double amount,
      Map<String, dynamic> earningsData,
      ScaffoldMessengerState? messenger) async {
    print('DEBUG: Processing payment of \$$amount for teacher $teacherId.');
    try {
      final calculatedEarnings = earningsData['calculatedEarnings'] as double;
      final earningsBreakdown =
          earningsData['earningsBreakdown'] as List<dynamic>;
      final studentsPaidFor = earningsData['studentsPaidFor'] as List<dynamic>;
      final lastPaymentDate = earningsData['lastPaymentDate'] as DateTime;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final teacherDocRef =
            FirebaseFirestore.instance.collection('teachers').doc(teacherId);
        final paymentCollectionRef =
            FirebaseFirestore.instance.collection('teacher_payments');

        // Get the current teacher document within the transaction
        final teacherSnapshot = await transaction.get(teacherDocRef);
        final currentRemainingBalance =
            (teacherSnapshot.data()?['remainingBalance'] as num?)?.toDouble() ??
                0.0;
        final newRemainingBalance =
            (currentRemainingBalance + calculatedEarnings) - amount;

        print(
            'DEBUG: Old remaining balance: \$$currentRemainingBalance, New remaining balance: \$$newRemainingBalance');

        // Update the teacher's remaining balance
        transaction.update(teacherDocRef, {
          'remainingBalance': newRemainingBalance,
          'lastPaymentDate': FieldValue
              .serverTimestamp(), // Update last payment date on the teacher document
        });

        // Add a new payment history record with all the calculated details
        transaction.set(paymentCollectionRef.doc(), {
          'teacherId': teacherId,
          'teacherName': teacherSnapshot.data()?['fullName'] ?? '',
          'paidAmount': amount,
          'calculatedEarnings': calculatedEarnings,
          'remainingBalance': newRemainingBalance,
          'paymentDate': FieldValue.serverTimestamp(),
          'lastPaymentDate': Timestamp.fromDate(lastPaymentDate),
          'earningsBreakdown': earningsBreakdown,
          'studentsPaidFor': studentsPaidFor,
        });
        print('DEBUG: Transaction committed. New payment record created.');
      });

      messenger?.showSnackBar(
        SnackBar(
          content: Text('Paid \$${amount.toStringAsFixed(2)} successfully!'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      log('Error processing payment: $e');
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Failed to process payment: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // New method to show the payment dialog with a text field
  void _showPayDialog(
      BuildContext context, double totalRemainingBalance) async {
    print(
        'DEBUG: _showPayDialog called. Total remaining balance: \$$totalRemainingBalance');

    // Fetch the last payment date
    final teacherDoc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(widget.teacherId)
        .get();
    final lastPaymentDate =
        (teacherDoc.data()?['lastPaymentDate'] as Timestamp?)?.toDate() ??
            DateTime(2000);

    // Calculate the earnings and breakdown for the current period
    final earningsData =
        await _calculateEarnings(widget.teacherId, lastPaymentDate);
    final calculatedEarnings = earningsData['calculatedEarnings'] as double;

    // Total amount to be paid is new earnings + existing remaining balance
    final totalPayableAmount = calculatedEarnings + totalRemainingBalance;

    final amountController =
        TextEditingController(text: totalPayableAmount.toStringAsFixed(2));
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) {
        print('DEBUG: Building dialog with StatefulBuilder.');
        return StatefulBuilder(
          builder: (BuildContext statefulDialogContext, StateSetter setState) {
            print(
                'DEBUG: StatefulBuilder rebuild triggered. errorText: $errorText');
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: const Text(
                'Enter Payment Amount',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Payable: \$${totalPayableAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.red,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount to pay',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      prefixText: '\$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      errorText: errorText,
                    ),
                    onChanged: (value) {
                      print('DEBUG: TextField onChanged called. Value: $value');
                      setState(() {
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          errorText = 'Please enter a valid amount.';
                          print('DEBUG: Input is invalid. errorText updated.');
                        } else if (amount > totalPayableAmount) {
                          errorText =
                              'Amount cannot exceed the total payable amount.';
                          print(
                              'DEBUG: Amount exceeds balance. errorText updated.');
                        } else {
                          errorText = null;
                          print('DEBUG: Input is valid. errorText cleared.');
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: errorText == null &&
                          amountController.text.isNotEmpty &&
                          !_isProcessing
                      ? () async {
                          setState(() {
                            _isProcessing = true;
                          });
                          final amount = double.parse(amountController.text);
                          try {
                            // Combine earnings data and last payment date
                            final combinedData = {
                              ...earningsData,
                              'lastPaymentDate': lastPaymentDate,
                            };
                            await _processPayment(
                                widget.teacherId,
                                amount,
                                combinedData,
                                _scaffoldMessengerKey.currentState);
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                              });
                            }
                          }
                          Navigator.of(dialogContext).pop();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Pay'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldMessengerKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.teacherName} History',
            style: const TextStyle(color: AppColors.textOnPrimary)),
        backgroundColor: AppColors.appBar,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
      ),
      body: Column(
        children: [
          _buildRemainingBalanceSection(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('teacher_payments')
                  .where('teacherId', isEqualTo: widget.teacherId)
                  .orderBy('paymentDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Something went wrong: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No payment history found.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16)));
                }
                final payments = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final doc = payments[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final paymentId = doc.id;
                    final paymentDate =
                        (data['paymentDate'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                    final formattedDate =
                        DateFormat('MMM d, yyyy').format(paymentDate);
                    final paidAmount =
                        (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
                    final calculatedEarnings =
                        (data['calculatedEarnings'] as num?)?.toDouble() ?? 0.0;
                    final remainingBalance =
                        (data['remainingBalance'] as num?)?.toDouble() ?? 0.0;

                    final isLastPayment = index == 0;

                    return Dismissible(
                      key: Key(paymentId),
                      direction: isLastPayment
                          ? DismissDirection.endToStart
                          : DismissDirection.none,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        color: AppColors.red,
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (!isLastPayment) return false;
                        return await showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return AlertDialog(
                              backgroundColor: AppColors.cardBackground,
                              title: const Text('Confirm Deletion',
                                  style:
                                      TextStyle(color: AppColors.textPrimary)),
                              content: const Text(
                                  'Are you sure you want to delete this payment? This action is irreversible.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel',
                                      style: TextStyle(
                                          color: AppColors.textSecondary)),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        if (isLastPayment) {
                          _deletePayment(paymentId, widget.teacherId,
                              _scaffoldMessengerKey.currentState);
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentDetailsPage(
                                  paymentData: data,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment on $formattedDate',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Paid: \$${paidAmount.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(color: AppColors.green),
                                      ),
                                      Text(
                                        'Calculated: \$${calculatedEarnings.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                                color: AppColors.primary),
                                      ),
                                      if (remainingBalance > 0)
                                        Text(
                                          'Unpaid from this payment: \$${remainingBalance.toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: AppColors.red),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildRemainingBalanceSection(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final totalRemainingBalance =
            (data['remainingBalance'] as num?)?.toDouble() ?? 0.0;

        if (totalRemainingBalance <= 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(15),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              Text(
                'Total Remaining Balance: \$${totalRemainingBalance.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.red,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _showPayDialog(context, totalRemainingBalance),
                icon:
                    const Icon(Icons.attach_money_rounded, color: Colors.white),
                label: const Text('Pay Remaining Balance',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
