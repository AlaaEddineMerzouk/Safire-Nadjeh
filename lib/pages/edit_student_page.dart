// 📁 lib/pages/edit_student_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:privateecole/constants/app_colors.dart';
import 'package:privateecole/widgets/custom_text_field.dart';

class EditStudentPage extends StatefulWidget {
  final String studentId;
  final Map<String, dynamic> studentData;

  const EditStudentPage({
    Key? key,
    required this.studentId,
    required this.studentData,
  }) : super(key: key);

  @override
  State<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends State<EditStudentPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _studentNameController;
  late TextEditingController _phoneController;
  late DateTime? _selectedBirthday;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _studentNameController =
        TextEditingController(text: widget.studentData['studentName']);
    _phoneController =
        TextEditingController(text: widget.studentData['phone'] ?? '');
    _selectedBirthday =
        (widget.studentData['birthday'] as Timestamp?)?.toDate();
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
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
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> updateData = {
        'studentName': _studentNameController.text.trim(),
        'birthday': _selectedBirthday,
      };

      // Conditionally add or delete the phone number field
      if (_phoneController.text.trim().isNotEmpty) {
        updateData['phone'] = _phoneController.text.trim();
      } else {
        updateData['phone'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student updated successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update student: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Student'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _studentNameController,
                labelText: 'Student Name',
                icon: Icons.person_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter student name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneController,
                labelText: 'Phone Number (Optional)',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                // The validator is removed to make the field optional
                validator: null,
              ),
              const SizedBox(height: 16),
              _buildDateSelector(
                label: 'Birthday (Optional)',
                date: _selectedBirthday,
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(
      {required String label,
      required DateTime? date,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.inputFill,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.orange, width: 2.0),
          ),
          prefixIcon: const Icon(Icons.cake_rounded, color: AppColors.primary),
        ),
        child: Text(
          date != null
              ? DateFormat('dd/MM/yyyy').format(date)
              : 'Select a date',
          style: TextStyle(
            color:
                date != null ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
