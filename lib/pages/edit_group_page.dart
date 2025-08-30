// 📁 lib/pages/edit_group_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';

class EditGroupPage extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> initialData;

  const EditGroupPage({
    Key? key,
    required this.groupId,
    required this.initialData,
  }) : super(key: key);

  @override
  State<EditGroupPage> createState() => _EditGroupPageState();
}

class _EditGroupPageState extends State<EditGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _priceController = TextEditingController(); // Added controller

  String? _selectedTeacherId;

  @override
  void initState() {
    super.initState();
    _groupNameController.text =
        widget.initialData['groupName'] as String? ?? '';
    // Initialize price controller from initialData
    _priceController.text =
        (widget.initialData['pricePerStudent'] as num? ?? 0).toString();
    _selectedTeacherId = widget.initialData['teacherId'] as String?;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _priceController.dispose(); // Dispose the new controller
    super.dispose();
  }

  Future<void> _updateGroup() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'groupName': _groupNameController.text.trim(),
        'pricePerStudent': double.parse(_priceController.text), // Updated field
        'teacherId': _selectedTeacherId,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update group: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Group',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _groupNameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon:
                      const Icon(Icons.group_work, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a group name' : null,
              ),
              const SizedBox(height: 24),

              // New Price per session input field
              TextFormField(
                controller: _priceController,
                style: const TextStyle(color: AppColors.textPrimary),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price per session',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon:
                      const Icon(Icons.attach_money, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('teachers').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text(
                        'No teachers available. Please add a teacher first.');
                  }

                  final teachers = snapshot.data!.docs;

                  final dropdownItems = [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Not Assigned'),
                    ),
                  ];
                  dropdownItems.addAll(teachers.map((doc) {
                    final teacherData = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(teacherData['fullName'] as String),
                    );
                  }).toList());

                  return DropdownButtonFormField<String>(
                    style: const TextStyle(color: AppColors.textPrimary),
                    dropdownColor: AppColors.inputFill,
                    decoration: InputDecoration(
                      labelText: 'Select Teacher',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      prefixIcon:
                          const Icon(Icons.school, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    value: _selectedTeacherId,
                    items: dropdownItems,
                    onChanged: (String? newValue) {
                      setState(() => _selectedTeacherId = newValue);
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Update Group'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
