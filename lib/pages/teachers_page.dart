// 📁 lib/pages/teachers_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../widgets/teacher_filter_bar.dart';
import '../widgets/teacher_card.dart';
import 'add_teacher_page.dart';
import 'edit_teacher_page.dart';
import 'teacher_payment_history_page.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({Key? key}) : super(key: key);

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  String _searchQuery = '';
  String _sortCriterion = 'Name';
  bool _isDescending = false;

  Stream<QuerySnapshot> _getTeachersStream() {
    Query query = FirebaseFirestore.instance.collection('teachers');

    if (_sortCriterion == 'Name') {
      query = query.orderBy('fullName', descending: _isDescending);
    } else if (_sortCriterion == 'Subject') {
      query = query.orderBy('subject', descending: _isDescending);
    } else if (_sortCriterion == 'Total Sessions') {
      query = query.orderBy('totalSessions', descending: _isDescending);
    } else if (_sortCriterion == 'Total Earnings') {
      query = query.orderBy('totalEarnings', descending: _isDescending);
    }

    return query.snapshots();
  }

  void _recordPayment(String docId, Map<String, dynamic> teacherData) async {
    final double totalEarnings =
        (teacherData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final int totalSessions = teacherData['totalSessions'] ?? 0;

    if (totalEarnings == 0.0 && totalSessions == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No earnings or sessions to pay.'),
              backgroundColor: AppColors.red),
        );
      }
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final paymentRef =
          FirebaseFirestore.instance.collection('teacher_payments').doc();
      batch.set(paymentRef, {
        'teacherId': docId,
        'fullName': teacherData['fullName'],
        'amount': totalEarnings,
        'sessionsPaid': totalSessions,
        'paymentDate': FieldValue.serverTimestamp(),
      });

      final teacherRef =
          FirebaseFirestore.instance.collection('teachers').doc(docId);
      batch.update(teacherRef, {
        'totalEarnings': 0,
        'totalSessions': 0,
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment recorded successfully!'),
              backgroundColor: AppColors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to record payment: $e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _showPayConfirmation(
      BuildContext context, String docId, Map<String, dynamic> teacherData) {
    final double totalEarnings =
        (teacherData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    final int totalSessions = teacherData['totalSessions'] ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirm Payment',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'Are you sure you want to pay ${teacherData['fullName']} for $totalSessions sessions, totaling \$${totalEarnings.toStringAsFixed(2)}?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                _recordPayment(docId, teacherData);
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _recordSession(String docId, Map<String, dynamic> teacherData) async {
    final double sessionPrice =
        (teacherData['sessionPrice'] as num?)?.toDouble() ?? 0.0;
    final int newTotalSessions = (teacherData['totalSessions'] ?? 0) + 1;
    final double newTotalEarnings =
        ((teacherData['totalEarnings'] as num?)?.toDouble() ?? 0.0) +
            sessionPrice;

    await FirebaseFirestore.instance.collection('teachers').doc(docId).update({
      'totalSessions': newTotalSessions,
      'totalEarnings': newTotalEarnings,
    });
  }

  void _showRecordSessionConfirmation(
      BuildContext context, String docId, Map<String, dynamic> teacherData) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirm Session',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'Are you sure you want to record a new session for ${teacherData['fullName']}?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                _recordSession(docId, teacherData);
                Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Session recorded successfully!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Are you sure you want to delete this teacher and all their payment history?',
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
                  final batch = FirebaseFirestore.instance.batch();
                  final paymentsSnapshot = await FirebaseFirestore.instance
                      .collection('teacher_payments')
                      .where('teacherId', isEqualTo: docId)
                      .get();

                  for (var doc in paymentsSnapshot.docs) {
                    batch.delete(doc.reference);
                  }

                  batch.delete(FirebaseFirestore.instance
                      .collection('teachers')
                      .doc(docId));

                  await batch.commit();

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Teacher and all related payments deleted successfully!'),
                        backgroundColor: AppColors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to delete teacher and payments: $e'),
                        backgroundColor: AppColors.red,
                      ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AddTeacherPage()));
        },
      ),
      body: Column(
        children: [
          TeacherFilterBar(
            searchQuery: _searchQuery,
            sortCriterion: _sortCriterion,
            isDescending: _isDescending,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            onSortCriterionChanged: (value) =>
                setState(() => _sortCriterion = value),
            onSortDirectionChanged: () =>
                setState(() => _isDescending = !_isDescending),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getTeachersStream(),
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
                    child: Text('No teachers found.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final teacherName =
                      (doc.data() as Map<String, dynamic>)['fullName']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                  return teacherName.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('No teachers match your search.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;

                    final totalEarnings = data['totalEarnings'];
                    final totalEarningsDouble = (totalEarnings is int)
                        ? totalEarnings.toDouble()
                        : (totalEarnings as double? ?? 0.0);

                    final totalSessions = data['totalSessions'] as int? ?? 0;

                    return TeacherCard(
                      fullName: data['fullName'] ?? '',
                      subject: data['subject'] ?? 'N/A',
                      totalSessions: totalSessions,
                      totalEarnings: totalEarningsDouble,
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditTeacherPage(
                                teacherData: data, docId: docId),
                          ),
                        );
                      },
                      onDelete: () => _showDeleteConfirmation(context, docId),
                      onRecordSession: () =>
                          _showRecordSessionConfirmation(context, docId, data),
                      onPay: () => _showPayConfirmation(context, docId, data),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeacherPaymentHistoryPage(
                              teacherId: docId,
                              teacherName: data['fullName'] ?? '',
                            ),
                          ),
                        );
                      },
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
}
