import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:privateecole/constants/app_colors.dart';

class AttendanceHistoryPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const AttendanceHistoryPage({
    Key? key,
    required this.studentId,
    required this.studentName,
  }) : super(key: key);

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  String? _selectedSubject;
  List<String> _availableSubjects = [];
  bool _isLoadingSubjects = true;

  @override
  void initState() {
    super.initState();
    // Fetch the list of subjects for the student when the page loads.
    _fetchStudentSubjects();
  }

  Future<void> _fetchStudentSubjects() async {
    try {
      final subscriptionsQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      final subjects = <String>{};
      for (var doc in subscriptionsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('subjects') && data['subjects'] is List) {
          subjects.addAll(
              (data['subjects'] as List).map((e) => e.toString()).toSet());
        }
      }

      setState(() {
        _availableSubjects = subjects.toList();
        if (_availableSubjects.isNotEmpty) {
          _selectedSubject = _availableSubjects.first;
        }
        _isLoadingSubjects = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSubjects = false;
      });
      // In a real app, you might want to show a more user-friendly error.
      debugPrint('Failed to fetch subjects: $e');
    }
  }

  // Function to delete an attendance record
  Future<void> _deleteRecord(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance record deleted successfully.'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error deleting record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete attendance record.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // Function to show a confirmation dialog before deleting
  Future<bool> _showDeleteConfirmation(
      BuildContext context, String date, String status) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Confirm Deletion',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete the attendance record for $date with status "$status"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(false), // Return false on cancel
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.orange)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(true), // Return true on delete
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    return result ?? false; // Return false if the dialog is dismissed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${widget.studentName} History',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.cardBackground,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          _buildSubjectFilter(),
          Expanded(
            child: _isLoadingSubjects
                ? const Center(child: CircularProgressIndicator())
                : _selectedSubject == null
                    ? const Center(
                        child: Text(
                          'No subjects found for this student.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectFilter() {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _selectedSubject,
        dropdownColor: AppColors.inputFill,
        isExpanded: true,
        items: _availableSubjects.map((subjectName) {
          return DropdownMenuItem<String>(
            value: subjectName,
            child: Text(subjectName, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (String? newSubject) {
          setState(() {
            _selectedSubject = newSubject;
          });
        },
        decoration: InputDecoration(
          labelText: 'Select Subject',
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.orange, width: 2.0),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    return StreamBuilder<QuerySnapshot>(
      // Removed the `.where('status', isEqualTo: 'Present')` line to show all records
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: widget.studentId)
          .where('subject', isEqualTo: _selectedSubject)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No attendance records found for this subject.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          );
        }

        final records = snapshot.data!.docs;
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final data = record.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final status = data['status'] ?? 'N/A';
            final subject = data['subject'] ?? 'N/A';
            final isPresent = status == 'Present';

            return Dismissible(
              key: ValueKey(record.id), // Unique key for the item
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                color: AppColors.red,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete_forever, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await _showDeleteConfirmation(context,
                    DateFormat('d MMMM y, h:mm a').format(date), status);
              },
              onDismissed: (direction) {
                _deleteRecord(record.id);
              },
              child: Card(
                color: AppColors.cardBackground,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    DateFormat('d MMMM y, h:mm a').format(date),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Subject: $subject',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Text(
                    status,
                    style: TextStyle(
                      color: isPresent ? AppColors.green : AppColors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
