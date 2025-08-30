// 📁 lib/pages/add_subscription_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key});

  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();

  final _priceController = TextEditingController();

  DateTime? _paymentDate;
  DateTime? _endDate;
  DateTime? _firstLessonDate;

  String? _selectedStudentId;
  String? _selectedStudentName;
  final List<String> _selectedGroupIds = [];

  late Future<QuerySnapshot> _studentsFuture;
  late Future<QuerySnapshot> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _studentsFuture = FirebaseFirestore.instance.collection('students').get();
    _groupsFuture = FirebaseFirestore.instance.collection('groups').get();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a student')),
        );
      }
      return;
    }
    if (_selectedGroupIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one group')),
        );
      }
      return;
    }

    if (_paymentDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a payment date')),
        );
      }
      return;
    }

    final bool hasExpired =
        _endDate != null ? _endDate!.isBefore(DateTime.now()) : false;
    final bool hasPresentAfterExpired = _endDate != null
        ? await _hasPresentAfterExpired(_selectedStudentId!, _endDate!)
        : false;

    try {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        "studentId": _selectedStudentId,
        "price": double.tryParse(_priceController.text.trim()) ?? 0,
        "groupIds": _selectedGroupIds,
        "paymentDate": Timestamp.fromDate(_paymentDate!),
        "endDate": _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        "firstLessonDate": _firstLessonDate != null
            ? Timestamp.fromDate(_firstLessonDate!)
            : null,
        "createdAt": Timestamp.now(),
        "hasExpired": hasExpired,
        "hasPresentAfterExpired": hasPresentAfterExpired,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save subscription: $e')),
        );
      }
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

    if (!mounted) {
      return;
    }

    final selectedStudent = await showDialog<QueryDocumentSnapshot>(
      context: context,
      builder: (context) {
        return _StudentSearchDialog(students: students);
      },
    );

    if (selectedStudent != null) {
      if (!mounted) return;
      setState(() {
        _selectedStudentId = selectedStudent.id;
        _selectedStudentName = selectedStudent['studentName'] as String;
      });
    }
  }

  Future<void> _showGroupMultiSelectDialog() async {
    final groupSnapshot = await _groupsFuture;
    final groups = groupSnapshot.docs;
    if (!mounted) {
      return;
    }

    final selectedGroups = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return _GroupMultiSelectDialog(
          groups: groups,
          initialSelectedGroupIds: _selectedGroupIds,
        );
      },
    );

    if (selectedGroups != null) {
      if (!mounted) return;
      setState(() {
        _selectedGroupIds.clear();
        _selectedGroupIds.addAll(selectedGroups);
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
                InkWell(
                  onTap: _showGroupMultiSelectDialog,
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
                        FutureBuilder<QuerySnapshot>(
                          future: _groupsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Text('Loading groups...');
                            }
                            if (snapshot.hasError) {
                              return const Text('Error loading groups');
                            }
                            final groups = snapshot.data!.docs;
                            final selectedGroupNames =
                                _selectedGroupIds.map((id) {
                              final matchingGroups =
                                  groups.where((doc) => doc.id == id);
                              if (matchingGroups.isNotEmpty) {
                                return matchingGroups.first['groupName']
                                    as String;
                              } else {
                                return '';
                              }
                            }).toList();

                            String displayText = _selectedGroupIds.isEmpty
                                ? 'Select Groups'
                                : selectedGroupNames
                                    .where((name) => name.isNotEmpty)
                                    .join(', ');

                            return Expanded(
                              child: Text(
                                displayText,
                                style: TextStyle(
                                  color: _selectedGroupIds.isNotEmpty
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                        const Icon(Icons.arrow_drop_down,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDateField("Payment Date", _paymentDate,
                    (date) => setState(() => _paymentDate = date)),
                const SizedBox(height: 16),
                _buildDateField(
                    "First Lesson Date (Optional)",
                    _firstLessonDate,
                    (date) => setState(() => _firstLessonDate = date)),
                const SizedBox(height: 16),
                _buildDateField("End Date (Optional)", _endDate,
                    (date) => setState(() => _endDate = date)),
                const SizedBox(height: 16),
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

class _GroupMultiSelectDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> groups;
  final List<String> initialSelectedGroupIds;

  const _GroupMultiSelectDialog({
    Key? key,
    required this.groups,
    required this.initialSelectedGroupIds,
  }) : super(key: key);

  @override
  State<_GroupMultiSelectDialog> createState() =>
      _GroupMultiSelectDialogState();
}

class _GroupMultiSelectDialogState extends State<_GroupMultiSelectDialog> {
  late List<String> _selectedGroupIds;

  @override
  void initState() {
    super.initState();
    _selectedGroupIds = List.from(widget.initialSelectedGroupIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Groups'),
      backgroundColor: AppColors.cardBackground,
      content: SingleChildScrollView(
        child: ListBody(
          children: widget.groups.map((group) {
            final groupName = group['groupName'] as String;
            final isSelected = _selectedGroupIds.contains(group.id);
            return CheckboxListTile(
              title: Text(groupName),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedGroupIds.add(group.id);
                  } else {
                    _selectedGroupIds.remove(group.id);
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedGroupIds),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
