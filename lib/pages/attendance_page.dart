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
  String? _selectedSubject;
  DateTime _selectedDate = DateTime.now();

  Map<String, bool> _attendanceStatuses = {};
  Map<String, bool> _initialAttendanceStatuses = {};
  List<DocumentSnapshot>? _students;
  bool _isLoading = false;
  String _searchQuery = '';
  List<String> _availableSubjects = [];

  late Future<QuerySnapshot> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = FirebaseFirestore.instance.collection('groups').get();
  }

  Future<void> _fetchStudentsAndAttendance() async {
    if (_selectedGroupId == null || _selectedSubject == null) return;

    setState(() {
      _isLoading = true;
      _students = null;
    });

    try {
      final subscriptionsQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('groupId', isEqualTo: _selectedGroupId)
          .get();

      final subscriptionsWithSubject = subscriptionsQuery.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final subjects = data['subjects'] as List<dynamic>?;
        return subjects != null && subjects.contains(_selectedSubject);
      }).toList();

      final studentIds = subscriptionsWithSubject.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['studentId'] as String;
      }).toList();

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

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('groupId', isEqualTo: _selectedGroupId)
          .where('subject', isEqualTo: _selectedSubject)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date',
              isLessThan:
                  Timestamp.fromDate(startOfDay.add(const Duration(days: 1))))
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
        _initialAttendanceStatuses = Map.from(newAttendanceStatuses);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch students: $e')),
      );
    }
  }

  Future<void> _fetchSubjectsForGroup(String groupId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('groupId', isEqualTo: groupId)
          .get();

      final subjects = <String>{};
      for (var doc in snapshot.docs) {
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
          _fetchStudentsAndAttendance();
        } else {
          _selectedSubject = null;
          _students = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch subjects: $e')),
      );
    }
  }

  void _onGroupChanged(String? newGroupId) {
    setState(() {
      _selectedGroupId = newGroupId;
      _selectedSubject = null;
      _students = null;
      _attendanceStatuses.clear();
      _initialAttendanceStatuses.clear();
      _availableSubjects.clear();
    });
    if (newGroupId != null) {
      _fetchSubjectsForGroup(newGroupId);
    }
  }

  void _onSubjectChanged(String? newSubject) {
    setState(() {
      _selectedSubject = newSubject;
      _students = null;
      _attendanceStatuses.clear();
      _initialAttendanceStatuses.clear();
      _fetchStudentsAndAttendance();
    });
  }

  // Function to show the confirmation dialog and handle deletion
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
          'Are you sure you want to delete all attendance records for this group, subject, and date? This action cannot be undone.',
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

  // New function to delete all attendance records for the selected group, subject, and date
  Future<void> _deleteGroupAttendance() async {
    if (_selectedGroupId == null || _selectedSubject == null) return;

    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('groupId', isEqualTo: _selectedGroupId)
          .where('subject', isEqualTo: _selectedSubject)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No attendance records found to delete.')),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      setState(() {
        _attendanceStatuses.clear();
        _initialAttendanceStatuses.clear();
        _students = null;
      });
      _fetchStudentsAndAttendance();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'All attendance records for this group and date have been deleted.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete attendance: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFilterBar(),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedGroupId != null && _selectedSubject != null
                    ? _buildStudentAttendanceList()
                    : const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            'Please select a group and subject to mark attendance.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
            if (_selectedGroupId != null && _selectedSubject != null)
              _buildSaveButton(),
          ],
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
              const SizedBox(width: 10),
              if (_selectedGroupId != null)
                Expanded(child: _buildSubjectDropdown()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildDatePicker()),
              if (_selectedGroupId != null && _selectedSubject != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _showDeleteConfirmationDialog,
                  icon: const Icon(Icons.delete_forever, color: AppColors.red),
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

  Widget _buildSubjectDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSubject,
      dropdownColor: AppColors.inputFill,
      isExpanded: true,
      items: _availableSubjects.map((subjectName) {
        return DropdownMenuItem<String>(
          value: subjectName,
          child: Text(subjectName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: _onSubjectChanged,
      decoration: InputDecoration(
        labelText: 'Subject',
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
      return Center(
        child: Text(
          'No students in this group are subscribed to $_selectedSubject.',
          style: const TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
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
        child: Text(
          'No students found matching your search.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
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
              onChanged: (bool value) {
                setState(() {
                  _attendanceStatuses[studentId] = value;
                });
              },
              activeColor: AppColors.green,
              inactiveThumbColor: AppColors.red,
            ),
            onTap: () {
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
        onPressed: _saveAttendance,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: const Text('Save Attendance', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Future<DocumentSnapshot?> _getSubscriptionForStudent(String studentId) async {
    final subscriptions = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (subscriptions.docs.isNotEmpty) {
      return subscriptions.docs.first;
    }
    return null;
  }

  void _saveAttendance() async {
    final batch = FirebaseFirestore.instance.batch();
    final attendanceRef = FirebaseFirestore.instance.collection('attendance');
    final subscriptionsRef =
        FirebaseFirestore.instance.collection('subscriptions');

    final dateForSaving = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    for (final studentId in _attendanceStatuses.keys) {
      final isPresent = _attendanceStatuses[studentId];
      final status = isPresent! ? 'Present' : 'Absent';

      final attendanceQuery = await attendanceRef
          .where('studentId', isEqualTo: studentId)
          .where('subject', isEqualTo: _selectedSubject)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateForSaving))
          .where('date',
              isLessThan: Timestamp.fromDate(
                  dateForSaving.add(const Duration(days: 1))))
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        final docId = attendanceQuery.docs.first.id;
        batch.update(attendanceRef.doc(docId), {
          'status': status,
          'date': Timestamp.fromDate(_selectedDate),
        });
      } else {
        final studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .get();
        final studentName =
            (studentDoc.data()?['studentName'] as String?) ?? 'N/A';
        batch.set(attendanceRef.doc(), {
          'studentId': studentId,
          'studentName': studentName,
          'subject': _selectedSubject,
          'groupId': _selectedGroupId,
          'date': Timestamp.fromDate(_selectedDate),
          'status': status,
        });
      }

      // Check for attendance after subscription expiration
      if (isPresent) {
        final subscriptionDoc = await _getSubscriptionForStudent(studentId);
        if (subscriptionDoc != null) {
          final subscriptionData =
              subscriptionDoc.data() as Map<String, dynamic>;
          final endDate = (subscriptionData['endDate'] as Timestamp?)?.toDate();
          final hasPresentAfterExpired =
              subscriptionData['hasPresentAfterExpired'] ?? false;

          if (endDate != null &&
              _selectedDate.isAfter(endDate) &&
              !hasPresentAfterExpired) {
            batch.update(subscriptionsRef.doc(subscriptionDoc.id), {
              'hasPresentAfterExpired': true,
            });
          }
        }
      }
    }

    try {
      await batch.commit();

      setState(() {
        _initialAttendanceStatuses = Map.from(_attendanceStatuses);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save attendance: $e')),
      );
    }
  }
}
