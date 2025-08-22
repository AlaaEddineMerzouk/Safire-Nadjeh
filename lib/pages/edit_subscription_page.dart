import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class EditSubscriptionPage extends StatefulWidget {
  final Map<String, dynamic> subscriptionData;
  final String docId;

  const EditSubscriptionPage({
    Key? key,
    required this.subscriptionData,
    required this.docId,
  }) : super(key: key);

  @override
  _EditSubscriptionPageState createState() => _EditSubscriptionPageState();
}

class _EditSubscriptionPageState extends State<EditSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _studentNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _sessionsController = TextEditingController();

  DateTime? _selectedPaymentDate;
  DateTime? _selectedEndDate;
  DateTime? _selectedFirstLessonDate;

  String? _selectedGroupId;
  List<String> _selectedSubjects = [];

  late Future<QuerySnapshot> _groupsFuture;
  late Future<QuerySnapshot> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _studentNameController.text = widget.subscriptionData['studentName'] ?? '';
    _priceController.text =
        (widget.subscriptionData['price'] ?? 0.0).toString();
    _sessionsController.text =
        (widget.subscriptionData['numberOfSessions'] ?? 0).toString();

    _selectedGroupId = widget.subscriptionData['groupId'] as String?;
    _selectedSubjects =
        List<String>.from(widget.subscriptionData['subjects'] ?? []);

    _selectedPaymentDate =
        (widget.subscriptionData['paymentDate'] as Timestamp?)?.toDate();
    _selectedEndDate =
        (widget.subscriptionData['endDate'] as Timestamp?)?.toDate();
    _selectedFirstLessonDate =
        (widget.subscriptionData['firstLessonDate'] as Timestamp?)?.toDate();

    _groupsFuture = FirebaseFirestore.instance.collection('groups').get();
    _subjectsFuture = FirebaseFirestore.instance.collection('subjects').get();
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _priceController.dispose();
    _sessionsController.dispose();
    super.dispose();
  }

  String _determineStatus() {
    if (_selectedEndDate == null) {
      return 'Unknown';
    }
    return _selectedEndDate!.isAfter(DateTime.now()) ? 'Active' : 'Expired';
  }

  // This is the new function to check for attendance after expiration
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
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

      try {
        // Calculate the new fields based on the selected end date
        final bool hasExpired = _selectedEndDate != null
            ? _selectedEndDate!.isBefore(DateTime.now())
            : false;
        final bool hasPresentAfterExpired = await _hasPresentAfterExpired(
            widget.subscriptionData['studentId'], _selectedEndDate!);

        final updatedData = {
          'studentName': _studentNameController.text.trim(),
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'groupId': _selectedGroupId,
          'numberOfSessions': int.tryParse(_sessionsController.text) ?? 0,
          'subjects': _selectedSubjects,
          'status': _determineStatus(),
          'paymentDate': _selectedPaymentDate != null
              ? Timestamp.fromDate(_selectedPaymentDate!)
              : null,
          'endDate': _selectedEndDate != null
              ? Timestamp.fromDate(_selectedEndDate!)
              : null,
          'firstLessonDate': _selectedFirstLessonDate != null
              ? Timestamp.fromDate(_selectedFirstLessonDate!)
              : null,
          'hasExpired': hasExpired,
          'hasPresentAfterExpired': hasPresentAfterExpired,
        };

        await FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(widget.docId)
            .update(updatedData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription updated successfully!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update subscription: $e')),
        );
      }
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
        title: const Text(
          'Edit Subscription',
          style: TextStyle(color: AppColors.textOnPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
      ),
      body: Theme(
        data: Theme.of(context)
            .copyWith(inputDecorationTheme: inputDecorationTheme),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _studentNameController,
                  decoration: const InputDecoration(labelText: 'Student Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                  style: const TextStyle(color: AppColors.textPrimary),
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
                    final groupIds = groups.map((doc) => doc.id).toList();
                    if (!groupIds.contains(_selectedGroupId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _selectedGroupId = null;
                        });
                      });
                    }

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
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Number of Sessions'),
                  style: const TextStyle(color: AppColors.textPrimary),
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

                    final subjects = snapshot.data?.docs ?? [];
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
                _buildDateField("Payment Date", _selectedPaymentDate,
                    (date) => setState(() => _selectedPaymentDate = date)),
                const SizedBox(height: 16),
                _buildDateField("End Date", _selectedEndDate,
                    (date) => setState(() => _selectedEndDate = date)),
                const SizedBox(height: 16),
                _buildDateField("First Lesson Date", _selectedFirstLessonDate,
                    (date) => setState(() => _selectedFirstLessonDate = date)),
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
                    onPressed: _saveChanges,
                    child: const Text('Save Changes',
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
