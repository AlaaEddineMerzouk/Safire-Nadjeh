import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:privateecole/constants/app_colors.dart';
import 'package:privateecole/widgets/subscription_filter_bar.dart';
import 'package:privateecole/widgets/student_card.dart';
import 'package:privateecole/pages/add_student_page.dart';
import 'package:privateecole/pages/edit_student_page.dart';
import 'package:privateecole/pages/attendance_history_page.dart';

class ManageStudentsPage extends StatefulWidget {
  const ManageStudentsPage({Key? key}) : super(key: key);

  @override
  State<ManageStudentsPage> createState() => _ManageStudentsPageState();
}

class _ManageStudentsPageState extends State<ManageStudentsPage> {
  String _searchQuery = '';

  Stream<QuerySnapshot> _getStudentsStream() {
    Query query = FirebaseFirestore.instance
        .collection('students')
        .orderBy('studentName');

    if (_searchQuery.isNotEmpty) {
      // Case-insensitive search
      query = query
          .where('studentName', isGreaterThanOrEqualTo: _searchQuery)
          .where('studentName', isLessThan: _searchQuery + 'z');
    }

    return query.snapshots();
  }

  void _showDeleteConfirmation(
      BuildContext parentContext, String docId, String studentName) {
    showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text(
            'Confirm Deletion',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Are you sure you want to delete $studentName? This will not automatically delete their subscriptions or attendance records.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Dismiss the AlertDialog first
                Navigator.of(context).pop();

                try {
                  // Delete the student document
                  await FirebaseFirestore.instance
                      .collection('students')
                      .doc(docId)
                      .delete();

                  // Show the SnackBar using the parent context
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('Student $studentName deleted.')),
                  );
                } catch (e) {
                  // Show an error SnackBar
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('Failed to delete student: $e')),
                  );
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
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStudentPage()),
          );
        },
      ),
      body: Column(
        children: [
          SubscriptionFilterBar(
            searchQuery: _searchQuery,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            filterStatus: 'All',
            onFilterChanged: (value) {},
            sortCriterion: 'Name',
            onSortCriterionChanged: (value) {},
            isDescending: true,
            onSortDirectionChanged: () {},
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getStudentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  );
                }

                final students = snapshot.data!.docs;
                final filteredStudents = students.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentName =
                      data['studentName']?.toString().toLowerCase() ?? '';
                  return studentName.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredStudents.isEmpty) {
                  return Center(
                    child: Text(
                      'No students match your search.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    final data = student.data() as Map<String, dynamic>;

                    // Convert the birthday timestamp to a formatted string
                    String? birthdayString;
                    if (data['birthday'] is Timestamp) {
                      final birthdayTimestamp = data['birthday'] as Timestamp;
                      birthdayString = DateFormat('MMMM d, yyyy')
                          .format(birthdayTimestamp.toDate());
                    } else {
                      birthdayString = data['birthday'];
                    }

                    return StudentCard(
                      studentName: data['studentName'] ?? 'N/A',
                      studentId: student.id,
                      phone: data['phone'],
                      birthday: birthdayString,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendanceHistoryPage(
                              studentId: student.id,
                              studentName: data['studentName'] ?? 'N/A',
                            ),
                          ),
                        );
                      },
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditStudentPage(
                              studentId: student.id,
                              studentData: data,
                            ),
                          ),
                        );
                      },
                      onDelete: () {
                        _showDeleteConfirmation(context, student.id,
                            data['studentName'] ?? 'this student');
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
