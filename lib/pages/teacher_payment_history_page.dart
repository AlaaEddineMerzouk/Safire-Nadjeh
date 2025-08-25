// 📁 lib/pages/teacher_payment_history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class TeacherPaymentHistoryPage extends StatelessWidget {
  final String teacherId;
  final String teacherName;

  const TeacherPaymentHistoryPage({
    Key? key,
    required this.teacherId,
    required this.teacherName,
  }) : super(key: key);

  // A helper function to show a confirmation dialog before deleting a payment
  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Are you sure you want to permanently delete this payment?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Delete the payment document from Firestore
                  await FirebaseFirestore.instance
                      .collection('teacher_payments')
                      .doc(docId)
                      .delete();

                  // We pop the dialog using its specific context
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  // We now check if the parent widget is mounted and then use its context
                  // to show the SnackBar. This context is not tied to the dialog.
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Payment deleted successfully!'),
                          backgroundColor: AppColors.green),
                    );
                  }
                } catch (e) {
                  // Handle any errors that occur during deletion
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to delete payment: $e'),
                          backgroundColor: AppColors.red),
                    );
                  }
                }
              },
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '$teacherName Payments',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.cardBackground,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query the teacher_payments collection, filtering by teacherId
        stream: FirebaseFirestore.instance
            .collection('teacher_payments')
            .where('teacherId', isEqualTo: teacherId)
            .orderBy('paymentDate', descending: true) // Sort by date
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
              child: Text('No payment history found for this teacher.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            );
          }

          final paymentDocs = snapshot.data!.docs;

          return ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: paymentDocs.length,
            itemBuilder: (context, index) {
              final doc = paymentDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final sessionsPaid = data['sessionsPaid'] as int? ?? 0;
              final paymentDate =
                  (data['paymentDate'] as Timestamp?)?.toDate() ??
                      DateTime.now();
              final formattedDate =
                  DateFormat('MMMM d, yyyy h:mm a').format(paymentDate);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryBlue,
                    child: Icon(Icons.payments_rounded, color: Colors.white),
                  ),
                  title: Text(
                    'Payment of \$${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '$sessionsPaid sessions paid\n$formattedDate',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever_rounded,
                        color: AppColors.red),
                    onPressed: () => _showDeleteConfirmation(context, doc.id),
                    tooltip: 'Delete Payment',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
