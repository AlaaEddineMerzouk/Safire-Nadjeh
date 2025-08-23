// 📁 lib/pages/add_subscription_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../widgets/subscription_card.dart'; // Ensure this import is present

class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key});

  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();

  final _priceController = TextEditingController();
  final _sessionsController = TextEditingController();

  DateTime? _paymentDate;
  DateTime? _endDate;
  DateTime? _firstLessonDate;

  String? _selectedStudentId;
  String? _selectedStudentName;
  String? _selectedGroupId;
  final List<String> _selectedSubjects = [];

  late Future<QuerySnapshot> _studentsFuture;
  late Future<QuerySnapshot> _groupsFuture;
  late Future<QuerySnapshot> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _studentsFuture = FirebaseFirestore.instance.collection('students').get();
    _groupsFuture = FirebaseFirestore.instance.collection('groups').get();
    _subjectsFuture = FirebaseFirestore.instance.collection('subjects').get();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _sessionsController.dispose();
    super.dispose();
  }

  String _determineStatus() {
    if (_endDate == null) {
      return 'Unknown';
    }
    return _endDate!.isAfter(DateTime.now()) ? 'Active' : 'Expired';
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a group')),
      );
      return;
    }
    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject')),
      );
      return;
    }

    // Check if payment date is selected, it's still a required field
    if (_paymentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment date')),
      );
      return;
    }

    final String calculatedStatus = _determineStatus();
    final bool hasExpired =
        _endDate != null ? _endDate!.isBefore(DateTime.now()) : false;
    final bool hasPresentAfterExpired = _endDate != null
        ? await _hasPresentAfterExpired(_selectedStudentId!, _endDate!)
        : false;

    try {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        "studentId": _selectedStudentId,
        "studentName": _selectedStudentName,
        "price": double.tryParse(_priceController.text.trim()) ?? 0,
        "status": calculatedStatus,
        "groupId": _selectedGroupId,
        "subjects": _selectedSubjects,
        "numberOfSessions": int.tryParse(_sessionsController.text.trim()) ?? 0,
        "paymentDate": Timestamp.fromDate(_paymentDate!),
        "endDate": _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        "firstLessonDate": _firstLessonDate != null
            ? Timestamp.fromDate(_firstLessonDate!)
            : null,
        "createdAt": Timestamp.now(),
        "hasExpired": hasExpired, // New field
        "hasPresentAfterExpired": hasPresentAfterExpired, // New field
      });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save subscription: $e')),
      );
    }
  }

  Future<bool> _hasPresentAfterExpired(
      String studentId, DateTime endDate) async {
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'Present')
        .where('date', isGreaterThan: endDate)
        .limit(1)
        .get();

    return attendanceSnapshot.docs.isNotEmpty;
  }

  Future<void> _showDatePickerDialog(BuildContext context,
      DateTime? initialDate, ValueChanged<DateTime?> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.textOnPrimary,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
          dialogBackgroundColor: AppColors.cardBackground,
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _buildDateField(
      String label, DateTime? date, ValueChanged<DateTime?> onPicked) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return InkWell(
      onTap: () => _showDatePickerDialog(context, date, onPicked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null ? dateFormat.format(date) : label,
              style: TextStyle(
                color: date != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            Icon(Icons.calendar_today,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showStudentPickerDialog() async {
    final studentSnapshot = await _studentsFuture;
    final students = studentSnapshot.docs;

    final selectedStudent = await showDialog<QueryDocumentSnapshot>(
      context: context,
      builder: (context) {
        return _StudentSearchDialog(students: students);
      },
    );

    if (selectedStudent != null) {
      setState(() {
        _selectedStudentId = selectedStudent.id;
        _selectedStudentName = selectedStudent['studentName'] as String;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecorationTheme = InputDecorationTheme(
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        title: const Text('Add Subscription',
            style: TextStyle(color: AppColors.textOnPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
      ),
      body: Theme(
        data: Theme.of(context)
            .copyWith(inputDecorationTheme: inputDecorationTheme),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                InkWell(
                  onTap: _showStudentPickerDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedStudentName ?? 'Select Student',
                          style: TextStyle(
                            color: _selectedStudentName != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a price' : null,
                ),
                const SizedBox(height: 16),
                FutureBuilder<QuerySnapshot>(
                  future: _groupsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('Error fetching groups.'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text(
                              'No groups available. Please add a group first.'));
                    }

                    final groups = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Group',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      value: _selectedGroupId,
                      hint: const Text('Select a group'),
                      items: groups.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(doc['groupName'] as String),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGroupId = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a group' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sessionsController,
                  decoration:
                      const InputDecoration(labelText: 'Number of Sessions'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                FutureBuilder<QuerySnapshot>(
                  future: _subjectsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('Error fetching subjects.'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text(
                              'No subjects available. Please add a subject first.'));
                    }

                    final subjects = snapshot.data!.docs;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subjects',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: subjects.map((doc) {
                            final subjectName = (doc.data()
                                as Map<String, dynamic>)['name'] as String;
                            final isSelected =
                                _selectedSubjects.contains(subjectName);
                            return FilterChip(
                              label: Text(subjectName),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedSubjects.add(subjectName);
                                  } else {
                                    _selectedSubjects.remove(subjectName);
                                  }
                                });
                              },
                              backgroundColor: AppColors.backgroundLight,
                              selectedColor: AppColors.primary.withOpacity(0.1),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.inputBorder,
                                  width: 1.5,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildDateField("Payment Date", _paymentDate,
                    (date) => setState(() => _paymentDate = date)),
                const SizedBox(height: 16),
                _buildDateField("End Date (Optional)", _endDate,
                    (date) => setState(() => _endDate = date)),
                const SizedBox(height: 16),
                _buildDateField(
                    "First Lesson Date (Optional)",
                    _firstLessonDate,
                    (date) => setState(() => _firstLessonDate = date)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _saveSubscription,
                    child: const Text('Save Subscription',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentSearchDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> students;
  const _StudentSearchDialog({required this.students});

  @override
  State<_StudentSearchDialog> createState() => _StudentSearchDialogState();
}

class _StudentSearchDialogState extends State<_StudentSearchDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredStudents = widget.students.where((doc) {
      final name = doc['studentName'].toString().toLowerCase();
      final phone = (doc.data() as Map<String, dynamic>).containsKey('phone')
          ? doc['phone'].toString().toLowerCase()
          : '';
      return name.contains(_searchQuery.toLowerCase()) ||
          phone.contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      title: const Text('Select a Student'),
      backgroundColor: AppColors.cardBackground,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Search students',
                suffixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.inputFill,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = filteredStudents[index];
                  final studentName = student['studentName'] as String;
                  final phoneNumber = (student.data() as Map<String, dynamic>)
                          .containsKey('phone')
                      ? student['phone']
                      : 'No phone number';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(studentName),
                      subtitle: Text(phoneNumber),
                      onTap: () {
                        Navigator.of(context).pop(student);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
