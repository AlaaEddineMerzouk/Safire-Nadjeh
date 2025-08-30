// 📁 lib/pages/attendance_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import 'attendance_history_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String? _selectedGroupId;
  DateTime _selectedDate = DateTime.now();

  Map<String, bool> _attendanceStatuses = {};
  List<DocumentSnapshot>? _students;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String _searchQuery = '';

  late Future<QuerySnapshot> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = FirebaseFirestore.instance.collection('groups').get();
  }

  Future<void> _fetchStudentsAndAttendance() async {
    if (_selectedGroupId == null) return;

    setState(() {
      _isLoading = true;
      _students = null;
    });

    try {
      final subscriptionsQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('groupIds', arrayContains: _selectedGroupId)
          .get();

      final studentIds = subscriptionsQuery.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['studentId'] as String;
          })
          .toSet()
          .toList();

      if (studentIds.isEmpty) {
        setState(() {
          _students = [];
          _isLoading = false;
        });
        return;
      }

      final studentsQuery = await FirebaseFirestore.instance
          .collection('students')
          .where(FieldPath.documentId, whereIn: studentIds)
          .get();

      final startOfDay =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('groupId', isEqualTo: _selectedGroupId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final existingAttendance = {
        for (var doc in attendanceQuery.docs)
          doc['studentId'] as String: doc['status'] == 'Present'
      };

      final newAttendanceStatuses = <String, bool>{};
      for (var id in studentIds) {
        newAttendanceStatuses[id] = existingAttendance[id] ?? true;
      }

      setState(() {
        _students = studentsQuery.docs;
        _attendanceStatuses = newAttendanceStatuses;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch students: $e')),
        );
      }
    }
  }

  void _onGroupChanged(String? newGroupId) {
    setState(() {
      _selectedGroupId = newGroupId;
      _students = null;
      _attendanceStatuses.clear();
    });
    if (newGroupId != null) {
      _fetchStudentsAndAttendance();
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Confirm Deletion',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete all attendance records for this group and date? This action cannot be undone.',
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

    if (confirmed == true) {
      _deleteGroupAttendance();
    }
  }

  Future<void> _deleteGroupAttendance() async {
    if (_selectedGroupId == null || _isDeleting) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('groupId', isEqualTo: _selectedGroupId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No attendance records found to delete.')),
          );
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (mounted) {
        _fetchStudentsAndAttendance();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Attendance records for this date have been deleted.'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete attendance: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: AbsorbPointer(
          absorbing: _isLoading || _isSaving || _isDeleting,
          child: Column(
            children: [
              _buildFilterBar(),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedGroupId != null
                      ? _buildStudentAttendanceList()
                      : const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Please select a group to mark attendance.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
              if (_selectedGroupId != null) _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSearchBox(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildGroupDropdown()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildDatePicker()),
              if (_selectedGroupId != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _isDeleting ? null : _showDeleteConfirmationDialog,
                  icon: _isDeleting
                      ? const CircularProgressIndicator(color: AppColors.red)
                      : const Icon(Icons.delete_forever, color: AppColors.red),
                  tooltip: 'Delete attendance for this date',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search by student name',
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange, width: 2.0),
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      style: const TextStyle(color: AppColors.textPrimary),
    );
  }

  Widget _buildGroupDropdown() {
    return FutureBuilder<QuerySnapshot>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.red)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No groups found.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        final groups = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          value: _selectedGroupId,
          dropdownColor: AppColors.inputFill,
          isExpanded: true,
          items: groups.map((doc) {
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(doc['groupName'] as String,
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: _onGroupChanged,
          decoration: InputDecoration(
            labelText: 'Group',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.orange, width: 2.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.cardBackground,
                  onSurface: AppColors.textPrimary,
                ),
                dialogBackgroundColor: AppColors.background,
              ),
              child: child!,
            );
          },
        );

        if (pickedDate != null) {
          if (mounted) {
            final pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(_selectedDate),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.cardBackground,
                      onSurface: AppColors.textPrimary,
                    ),
                    dialogBackgroundColor: AppColors.background,
                  ),
                  child: child!,
                );
              },
            );

            if (pickedTime != null) {
              final newDateTime = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
              if (newDateTime != _selectedDate) {
                setState(() {
                  _selectedDate = newDateTime;
                  _fetchStudentsAndAttendance();
                });
              }
            }
          }
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date and Time',
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.orange, width: 2.0),
          ),
          prefixIcon:
              const Icon(Icons.calendar_today, color: AppColors.primary),
        ),
        child: Text(
          DateFormat('dd/MM/yyyy h:mm a').format(_selectedDate),
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildStudentAttendanceList() {
    if (_students == null) {
      return const SizedBox.shrink();
    }

    if (_students!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No students found in this group\'s subscriptions.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final filteredStudents = _students!.where((student) {
      final studentData = student.data() as Map<String, dynamic>;
      final studentName =
          studentData['studentName']?.toString().toLowerCase() ?? '';
      return studentName.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredStudents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No students found matching your search.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: filteredStudents.map((studentDoc) {
        final studentData = studentDoc.data() as Map<String, dynamic>;
        final studentId = studentDoc.id;
        final studentName = studentData['studentName'] ?? 'N/A';

        final isPresent = _attendanceStatuses[studentId] ?? true;

        return Card(
          color: AppColors.cardBackground,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(studentName,
                style: const TextStyle(color: AppColors.textPrimary)),
            subtitle: Text('ID: ${studentId.substring(0, 5)}...',
                style: const TextStyle(color: AppColors.textSecondary)),
            trailing: Switch(
              value: isPresent,
              onChanged: _isSaving
                  ? null
                  : (bool value) {
                      setState(() {
                        _attendanceStatuses[studentId] = value;
                      });
                    },
              activeColor: AppColors.green,
              inactiveThumbColor: AppColors.red,
            ),
            onTap: _isSaving
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceHistoryPage(
                          studentId: studentId,
                          studentName: studentName,
                        ),
                      ),
                    );
                  },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveAttendance,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: AppColors.textOnPrimary,
                  strokeWidth: 2,
                ),
              )
            : const Text('Save Attendance', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final attendanceRef = FirebaseFirestore.instance.collection('attendance');
    final dateForSaving = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = dateForSaving.add(const Duration(days: 1));

    try {
      final existingAttendanceQuery = await attendanceRef
          .where('groupId', isEqualTo: _selectedGroupId)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateForSaving))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (existingAttendanceQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance for this date is already saved.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final studentId in _attendanceStatuses.keys) {
        final isPresent = _attendanceStatuses[studentId]!;
        final status = isPresent ? 'Present' : 'Absent';

        batch.set(attendanceRef.doc(), {
          'studentId': studentId,
          'groupId': _selectedGroupId,
          'date': Timestamp.fromDate(_selectedDate),
          'status': status,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save attendance: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
