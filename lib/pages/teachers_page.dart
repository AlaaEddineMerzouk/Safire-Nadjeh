import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../widgets/teacher_filter_bar.dart';
import 'add_teacher_page.dart';
import 'edit_teacher_page.dart';
import 'teacher_payment_history_page.dart';
import 'payment_details_page.dart';
import 'dart:developer';
import '../widgets/teacher_card.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({Key? key}) : super(key: key);

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  String _searchQuery = '';
  String _sortCriterion = 'Name';
  bool _isDescending = false;
  bool _isProcessing = false;

  late Future<List<Map<String, dynamic>>> _teachersFuture;

  @override
  void initState() {
    super.initState();
    _teachersFuture = _fetchAndProcessTeachers();
  }

  Future<List<Map<String, dynamic>>> _fetchAndProcessTeachers() async {
    debugPrint('Fetching and processing teachers...');
    final teachersSnapshot =
        await FirebaseFirestore.instance.collection('teachers').get();

    // 1. Filter documents based on search query
    final filteredDocs = teachersSnapshot.docs.where((doc) {
      final teacherName =
          (doc.data()['fullName'] as String?)?.toLowerCase() ?? '';
      return teacherName.contains(_searchQuery.toLowerCase());
    }).toList();

    // 2. Calculate earnings for each filtered teacher concurrently
    final List<Future<Map<String, dynamic>>> futures =
        filteredDocs.map((doc) async {
      final data = doc.data();
      final docId = doc.id;
      final groupIds = List<String>.from(data['groupIds'] ?? []);
      final lastPaymentDate = (data['lastPaymentDate'] as Timestamp?)?.toDate();
      final remainingBalance =
          (data['remainingBalance'] as num?)?.toDouble() ?? 0.0;

      final newEarningsData =
          await _calculateNewTeacherEarnings(docId, groupIds, lastPaymentDate);
      final newEarnings = newEarningsData['totalCalculatedEarnings'] as double;
      final totalStudentsPaidFor =
          newEarningsData['totalStudentsPaidFor'] as int;
      final totalPendingEarnings = newEarnings + remainingBalance;

      return {
        'docId': docId,
        'data': data,
        'newEarnings': newEarnings,
        'totalStudentsPaidFor': totalStudentsPaidFor,
        'totalPendingEarnings': totalPendingEarnings,
      };
    }).toList();

    final processedTeachers = await Future.wait(futures);

    // 3. Sort the processed list in memory
    processedTeachers.sort((a, b) {
      dynamic aValue, bValue;
      int comparison;

      switch (_sortCriterion) {
        case 'Name':
          aValue = (a['data']['fullName'] as String?) ?? '';
          bValue = (b['data']['fullName'] as String?) ?? '';
          comparison = aValue.compareTo(bValue);
          break;
        case 'Remaining Balance':
          aValue = (a['data']['remainingBalance'] as num?)?.toDouble() ?? 0.0;
          bValue = (b['data']['remainingBalance'] as num?)?.toDouble() ?? 0.0;
          comparison = aValue.compareTo(bValue);
          break;
        case 'Last Payment Date':
          aValue = (a['data']['lastPaymentDate'] as Timestamp?)?.toDate() ??
              DateTime(1900);
          bValue = (b['data']['lastPaymentDate'] as Timestamp?)?.toDate() ??
              DateTime(1900);
          comparison = aValue.compareTo(bValue);
          break;
        default:
          aValue = (a['data']['fullName'] as String?) ?? '';
          bValue = (b['data']['fullName'] as String?) ?? '';
          comparison = aValue.compareTo(bValue);
          break;
      }

      return _isDescending ? -comparison : comparison;
    });

    return processedTeachers;
  }

  Future<Map<String, dynamic>> _calculateNewTeacherEarnings(String teacherId,
      List<String> groupIds, DateTime? previousLastPaymentDate) async {
    double totalCalculatedEarnings = 0.0;
    int totalStudentsPaidFor = 0;
    List<Map<String, dynamic>> studentsPaidFor = [];
    final List<Map<String, dynamic>> earningsBreakdown = [];

    final teacherDoc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .get();
    final percentage =
        (teacherDoc.data()?['percentage'] as num? ?? 0.0).toDouble();

    if (groupIds.isEmpty) {
      return {
        'totalCalculatedEarnings': 0.0,
        'totalStudentsPaidFor': 0,
        'studentsPaidFor': [],
        'earningsBreakdown': [],
      };
    }

    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('groupId', whereIn: groupIds)
        .where('status', isEqualTo: 'Present')
        .where('date', isGreaterThan: previousLastPaymentDate ?? DateTime(2000))
        .get();

    final Map<String, int> studentsPerGroup = {};
    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final groupId = data['groupId'] as String;
      studentsPerGroup[groupId] = (studentsPerGroup[groupId] ?? 0) + 1;

      studentsPaidFor.add({
        'studentId': data['studentId'],
        'date': data['date'] as Timestamp,
        'groupId': data['groupId'],
      });
    }

    final groupsToFetch = studentsPerGroup.keys.toList();
    final groupDocs = await Future.wait(groupsToFetch.map(
        (id) => FirebaseFirestore.instance.collection('groups').doc(id).get()));
    final Map<String, DocumentSnapshot> groupDocMap = {
      for (var doc in groupDocs) doc.id: doc
    };

    for (var groupId in studentsPerGroup.keys) {
      final presentStudents = studentsPerGroup[groupId]!;
      final groupDoc = groupDocMap[groupId];

      if (groupDoc != null && groupDoc.exists) {
        final groupData = groupDoc.data() as Map<String, dynamic>;
        final pricePerStudent =
            (groupData['pricePerStudent'] as num?)?.toDouble() ?? 0.0;
        final groupEarnings =
            pricePerStudent * (percentage / 100) * presentStudents;

        if (groupEarnings > 0) {
          totalCalculatedEarnings += groupEarnings;
          earningsBreakdown.add({
            'groupId': groupId,
            'earnings': groupEarnings,
            'presentStudents': presentStudents,
          });
        }
      }
    }

    totalStudentsPaidFor = studentsPaidFor.length;

    return {
      'totalCalculatedEarnings': totalCalculatedEarnings,
      'totalStudentsPaidFor': totalStudentsPaidFor,
      'studentsPaidFor': studentsPaidFor,
      'earningsBreakdown': earningsBreakdown,
    };
  }

  Future<void> _recordPayment(
      String docId,
      Map<String, dynamic> teacherData,
      double paidAmount,
      double totalCalculatedEarnings,
      int totalStudentsPaidFor,
      List<Map<String, dynamic>> studentsPaidFor,
      List<Map<String, dynamic>> earningsBreakdown,
      DateTime? previousLastPaymentDate) async {
    final batch = FirebaseFirestore.instance.batch();
    final paymentRef =
        FirebaseFirestore.instance.collection('teacher_payments').doc();
    final newRemainingBalance = totalCalculatedEarnings - paidAmount;

    batch.set(paymentRef, {
      'teacherId': docId,
      'paidAmount': paidAmount,
      'calculatedEarnings': totalCalculatedEarnings,
      'totalStudentsPaidFor': totalStudentsPaidFor,
      'percentageApplied': teacherData['percentage'],
      'groupsPaidFor': teacherData['groupIds'],
      'paymentDate': FieldValue.serverTimestamp(),
      'studentsPaidFor': studentsPaidFor,
      'earningsBreakdown': earningsBreakdown,
      'lastPaymentDate': previousLastPaymentDate != null
          ? Timestamp.fromDate(previousLastPaymentDate)
          : null,
      'remainingBalance': newRemainingBalance,
    });

    final teacherRef =
        FirebaseFirestore.instance.collection('teachers').doc(docId);
    batch.update(teacherRef, {
      'lastPaymentDate': FieldValue.serverTimestamp(),
      'remainingBalance': newRemainingBalance,
    });

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment recorded successfully!'),
            backgroundColor: AppColors.green));
        setState(() {
          _teachersFuture = _fetchAndProcessTeachers();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to record payment: $e'),
            backgroundColor: AppColors.red));
      }
    }
  }

  Future<void> _payRemainingBalance(
      String teacherId, String teacherName) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(teacherId)
          .get();
      if (!mounted) return;

      final teacherData = teacherDoc.data();
      if (teacherData == null) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Teacher data not found.'),
              backgroundColor: AppColors.red));
        return;
      }

      final currentRemainingBalance =
          (teacherData['remainingBalance'] as num?)?.toDouble() ?? 0.0;
      final previousLastPaymentDate =
          (teacherData['lastPaymentDate'] as Timestamp?)?.toDate();

      if (currentRemainingBalance <= 0) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No remaining balance to pay.'),
              backgroundColor: AppColors.red));
        return;
      }
      final groupIds = List<String>.from(teacherData['groupIds'] ?? []);
      final newEarningsData = await _calculateNewTeacherEarnings(
          teacherId, groupIds, previousLastPaymentDate);
      final newEarnings = newEarningsData['totalCalculatedEarnings'] as double;
      final totalStudentsPaidFor =
          newEarningsData['totalStudentsPaidFor'] as int;
      final studentsPaidFor =
          newEarningsData['studentsPaidFor'] as List<Map<String, dynamic>>;
      final earningsBreakdown =
          newEarningsData['earningsBreakdown'] as List<Map<String, dynamic>>;

      final totalPayableAmount = currentRemainingBalance + newEarnings;

      final finalEarningsBreakdown = [...earningsBreakdown];
      if (currentRemainingBalance > 0) {
        finalEarningsBreakdown.add({
          'groupId': 'remaining_balance_payoff',
          'earnings': currentRemainingBalance,
          'presentStudents': 0,
        });
      }

      final batch = FirebaseFirestore.instance.batch();
      final paymentRef =
          FirebaseFirestore.instance.collection('teacher_payments').doc();

      batch.set(paymentRef, {
        'teacherId': teacherId,
        'paidAmount': totalPayableAmount,
        'calculatedEarnings': totalPayableAmount,
        'totalStudentsPaidFor': totalStudentsPaidFor,
        'percentageApplied': teacherData['percentage'],
        'groupsPaidFor': teacherData['groupIds'],
        'paymentDate': FieldValue.serverTimestamp(),
        'studentsPaidFor': studentsPaidFor,
        'earningsBreakdown': finalEarningsBreakdown,
        'lastPaymentDate': previousLastPaymentDate != null
            ? Timestamp.fromDate(previousLastPaymentDate)
            : null,
        'remainingBalance': 0.0,
      });

      batch.update(
          FirebaseFirestore.instance.collection('teachers').doc(teacherId), {
        'lastPaymentDate': FieldValue.serverTimestamp(),
        'remainingBalance': 0.0,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Remaining balance paid successfully!'),
            backgroundColor: AppColors.green));
        setState(() {
          _teachersFuture = _fetchAndProcessTeachers();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to pay remaining balance: $e'),
            backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showPayConfirmation(BuildContext context, String docId,
      Map<String, dynamic> teacherData) async {
    final TextEditingController amountController = TextEditingController();
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(docId)
          .get();
      if (!mounted) return;
      final previousLastPaymentDate =
          (teacherDoc.data()?['lastPaymentDate'] as Timestamp?)?.toDate();
      final groupIds = List<String>.from(teacherData['groupIds'] ?? []);
      final existingRemainingBalance =
          (teacherData['remainingBalance'] as num?)?.toDouble() ?? 0.0;
      final percentage = (teacherData['percentage'] as num?)?.toDouble() ?? 0.0;

      final newEarningsData = await _calculateNewTeacherEarnings(
          docId, groupIds, previousLastPaymentDate);
      if (!mounted) return;

      final newEarnings = newEarningsData['totalCalculatedEarnings'] as double;
      final totalStudents = newEarningsData['totalStudentsPaidFor'] as int;
      final studentsPaidFor =
          newEarningsData['studentsPaidFor'] as List<Map<String, dynamic>>;
      final earningsBreakdown =
          newEarningsData['earningsBreakdown'] as List<Map<String, dynamic>>;
      final totalCalculatedEarnings = newEarnings + existingRemainingBalance;

      if (newEarnings <= 0 && existingRemainingBalance <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No new earnings or remaining balance to pay.'),
              backgroundColor: AppColors.red));
        }
        return;
      }

      if (mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setState) {
                double? paidAmount = double.tryParse(amountController.text);
                bool isButtonEnabled =
                    (paidAmount ?? totalCalculatedEarnings) <=
                            totalCalculatedEarnings &&
                        (paidAmount ?? 0) >= 0;
                String? errorMessage;
                if (paidAmount != null &&
                    paidAmount > totalCalculatedEarnings) {
                  errorMessage =
                      'Paid amount cannot be greater than total calculated earnings.';
                }

                return AlertDialog(
                  backgroundColor: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text('Pay ${teacherData['fullName']}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Earnings Summary:',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text(
                            'Teacher\'s percentage: ${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        const Divider(color: Color(0xFFD9D9D9)),
                        if (newEarnings <= 0)
                          const Text('No new earnings from groups this period.',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic))
                        else
                          ...earningsBreakdown
                              .map((e) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.group,
                                            size: 16, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child:
                                              FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('groups')
                                                .doc(e['groupId'])
                                                .get(),
                                            builder: (context, groupSnapshot) {
                                              if (groupSnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Text('Loading...',
                                                    style: TextStyle(
                                                        color: AppColors
                                                            .textSecondary));
                                              }
                                              final groupName =
                                                  (groupSnapshot.data?.data()
                                                              as Map<String,
                                                                  dynamic>?)?[
                                                          'groupName'] ??
                                                      'N/A';
                                              return Text(
                                                  '$groupName (${e['presentStudents']} students)',
                                                  style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary),
                                                  overflow:
                                                      TextOverflow.ellipsis);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                            '\$${e['earnings'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        if (existingRemainingBalance > 0) ...[
                          const Divider(color: Color(0xFFD9D9D9)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Text('Previous Balance:',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                                const Spacer(),
                                Text(
                                    '\$${existingRemainingBalance.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                        ],
                        const Divider(color: Color(0xFFD9D9D9)),
                        const SizedBox(height: 8),
                        const Text('Total Calculated Earnings:',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                        const SizedBox(height: 4),
                        Text('\$${totalCalculatedEarnings.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryOrange)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountController,
                          decoration: InputDecoration(
                            labelText: 'Final amount to pay (Optional)',
                            labelStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            hintText: 'Enter a custom amount or leave blank',
                            hintStyle: TextStyle(
                                color:
                                    AppColors.textSecondary.withOpacity(0.5)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFFD9D9D9))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: AppColors.primary)),
                            errorText: errorMessage,
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isButtonEnabled
                            ? AppColors.primaryOrange
                            : AppColors.textSecondary.withOpacity(0.5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isButtonEnabled
                          ? () {
                              final double paidAmount =
                                  double.tryParse(amountController.text) ??
                                      totalCalculatedEarnings;
                              _recordPayment(
                                  docId,
                                  teacherData,
                                  paidAmount,
                                  totalCalculatedEarnings,
                                  totalStudents,
                                  studentsPaidFor,
                                  earningsBreakdown,
                                  previousLastPaymentDate);
                              Navigator.of(dialogContext).pop();
                            }
                          : null,
                      child: const Text('Confirm Payment'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to calculate earnings: $e'),
            backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                if (mounted) {
                  setState(() {
                    _isProcessing = true;
                  });
                }
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Teacher and all related payments deleted successfully!'),
                        backgroundColor: AppColors.green));
                    setState(() {
                      _teachersFuture = _fetchAndProcessTeachers();
                    });
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Failed to delete teacher and payments: $e'),
                        backgroundColor: AppColors.red));
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isProcessing = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white),
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
        onPressed: _isProcessing
            ? null
            : () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddTeacherPage()));
              },
      ),
      body: Column(
        children: [
          TeacherFilterBar(
            searchQuery: _searchQuery,
            sortCriterion: _sortCriterion,
            isDescending: _isDescending,
            onSearchChanged: (value) => setState(() {
              _searchQuery = value;
              _teachersFuture = _fetchAndProcessTeachers();
            }),
            onSortCriterionChanged: (value) => setState(() {
              _sortCriterion = value;
              _teachersFuture = _fetchAndProcessTeachers();
            }),
            onSortDirectionChanged: () => setState(() {
              _isDescending = !_isDescending;
              _teachersFuture = _fetchAndProcessTeachers();
            }),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _teachersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Something went wrong: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.red)));
                }
                final processedTeachers = snapshot.data ?? [];

                if (processedTeachers.isEmpty) {
                  return const Center(
                      child: Text('No teachers found.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: processedTeachers.length,
                  itemBuilder: (context, index) {
                    final teacherData = processedTeachers[index];
                    final docId = teacherData['docId'] as String;
                    final data = teacherData['data'] as Map<String, dynamic>;
                    final totalPendingEarnings =
                        teacherData['totalPendingEarnings'] as double;
                    final totalStudentsPaidFor =
                        teacherData['totalStudentsPaidFor'] as int;
                    final remainingBalance =
                        (data['remainingBalance'] as num?)?.toDouble() ?? 0.0;
                    final groupIds = List<String>.from(data['groupIds'] ?? []);

                    return TeacherCard(
                      fullName: data['fullName'] ?? '',
                      percentage:
                          (data['percentage'] as num?)?.toDouble() ?? 0.0,
                      pendingEarnings: totalPendingEarnings,
                      totalStudentsPaidFor: totalStudentsPaidFor,
                      remainingBalance: remainingBalance,
                      groupIds: groupIds,
                      onEdit: _isProcessing
                          ? () {}
                          : () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => EditTeacherPage(
                                          docId: docId, teacherData: data)));
                            },
                      onDelete: _isProcessing
                          ? () {}
                          : () => _showDeleteConfirmation(context, docId),
                      onPay: _isProcessing
                          ? () {}
                          : () => _showPayConfirmation(context, docId, data),
                      onTap: _isProcessing
                          ? () {}
                          : () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          TeacherPaymentHistoryPage(
                                              teacherId: docId,
                                              teacherName:
                                                  data['fullName'] ?? '',
                                              onPayRemainingBalance:
                                                  _payRemainingBalance)));
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
