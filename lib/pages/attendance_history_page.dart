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
  String? _selectedGroupId;
  List<DocumentSnapshot> _availableGroups = [];
  bool _isLoadingGroups = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentGroups();
  }

  Future<void> _fetchStudentGroups() async {
    debugPrint('Fetching groups for student: ${widget.studentId}');
    try {
      final subscriptionsQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('studentId', isEqualTo: widget.studentId)
          .get();

      final groupIds = <String>{};
      for (var doc in subscriptionsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('groupIds') && data['groupIds'] is List) {
          groupIds.addAll(
              (data['groupIds'] as List).map((e) => e.toString()).toSet());
        }
      }
      debugPrint('Found groupIds in subscriptions: $groupIds');

      if (groupIds.isEmpty) {
        setState(() {
          _isLoadingGroups = false;
        });
        debugPrint('No group IDs found for this student. Hiding dropdown.');
        return;
      }

      final groupsQuery = await FirebaseFirestore.instance
          .collection('groups')
          .where(FieldPath.documentId, whereIn: groupIds.toList())
          .get();

      debugPrint('Found ${groupsQuery.docs.length} groups.');
      for (var doc in groupsQuery.docs) {
        debugPrint('Group ID: ${doc.id}, Name: ${doc['groupName']}');
      }

      setState(() {
        _availableGroups = groupsQuery.docs;
        if (_availableGroups.isNotEmpty) {
          _selectedGroupId = _availableGroups.first.id;
          debugPrint('Initial selected group ID: $_selectedGroupId');
        }
        _isLoadingGroups = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGroups = false;
        });
        debugPrint('Failed to fetch groups: $e');
      }
    }
  }

  Future<void> _deleteRecord(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance record deleted successfully.'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete attendance record.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

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
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
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
          _buildGroupFilter(),
          Expanded(
            child: _isLoadingGroups
                ? const Center(child: CircularProgressIndicator())
                : _selectedGroupId == null
                    ? const Center(
                        child: Text(
                          'No groups found for this student.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFilter() {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _selectedGroupId,
        dropdownColor: AppColors.inputFill,
        isExpanded: true,
        items: _availableGroups.map((groupDoc) {
          final groupName = groupDoc['groupName'] as String;
          return DropdownMenuItem<String>(
            value: groupDoc.id,
            child: Text(groupName, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (String? newGroupId) {
          setState(() {
            _selectedGroupId = newGroupId;
          });
          debugPrint('Selected new group ID: $_selectedGroupId');
        },
        decoration: InputDecoration(
          labelText: 'Select Group',
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
    debugPrint(
        'Building attendance list for student: ${widget.studentId} and group: $_selectedGroupId');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: widget.studentId)
          .where('groupId', isEqualTo: _selectedGroupId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('Stream is waiting for data...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Stream encountered an error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          debugPrint('Query returned no documents.');
          return const Center(
            child: Text(
              'No attendance records found for this group.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          );
        }

        debugPrint('Query returned ${snapshot.data!.docs.length} documents.');
        final records = snapshot.data!.docs;
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final data = record.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final status = data['status'] ?? 'N/A';
            final isPresent = status == 'Present';
            debugPrint('Displaying record for date: $date, status: $status');

            return Dismissible(
              key: ValueKey(record.id),
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
