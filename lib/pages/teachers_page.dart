import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../widgets/teacher_filter_bar.dart';
import '../widgets/teacher_card.dart';
import 'add_teacher_page.dart';
import 'edit_teacher_page.dart';

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

  void _recordSession(String docId, Map<String, dynamic> teacherData) async {
    // Correctly handle type casting for Firestore data
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
      builder: (context) {
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                // The fix: Removed 'await' here
                _recordSession(docId, teacherData);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Session recorded successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange, // or primaryOrange
                foregroundColor: Colors.white, // makes the text/icons white
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('Are you sure you want to delete this teacher?',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('teachers')
                    .doc(docId)
                    .delete();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Teacher deleted successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange, // or primaryOrange
                foregroundColor: Colors.white, // makes the text/icons white
              ),
              child: const Text('Confirm'),
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
        backgroundColor: AppColors.orange,
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
                          style: TextStyle(color: AppColors.red)));
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

                    // Handle potential type mismatch for totalEarnings
                    final totalEarnings = data['totalEarnings'];
                    final totalEarningsDouble = (totalEarnings is int)
                        ? totalEarnings.toDouble()
                        : (totalEarnings as double? ?? 0.0);

                    return TeacherCard(
                      fullName: data['fullName'] ?? '',
                      subject: data['subject'] ?? 'N/A',
                      totalSessions: data['totalSessions'] ?? 0,
                      totalEarnings: totalEarningsDouble,
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditTeacherPage(
                                teacherData: data, docId: doc.id),
                          ),
                        );
                      },
                      onDelete: () => _showDeleteConfirmation(context, doc.id),
                      onRecordSession: () =>
                          _showRecordSessionConfirmation(context, doc.id, data),
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
