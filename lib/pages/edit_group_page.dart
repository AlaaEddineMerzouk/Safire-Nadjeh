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

  String? _selectedTeacherId;
  final List<String> _selectedSubjects = [];

  final List<String> _availableSubjects = [
    "Math",
    "Science",
    "English",
    "History",
    "Physics",
    "Chemistry",
  ];

  @override
  void initState() {
    super.initState();
    _groupNameController.text =
        widget.initialData['groupName'] as String? ?? '';
    _selectedTeacherId = widget.initialData['teacherId'] as String?;
    _selectedSubjects.addAll(
        List<String>.from(widget.initialData['subjects'] as List? ?? []));
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _updateGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a teacher')),
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
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'groupName': _groupNameController.text.trim(),
        'teacherId': _selectedTeacherId,
        'subjects': _selectedSubjects,
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

                  // Add a "Not Assigned" option with a null value to the list
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
              const Text(
                'Subjects',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _availableSubjects.map((subject) {
                  final isSelected = _selectedSubjects.contains(subject);
                  return FilterChip(
                    label: Text(subject),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSubjects.add(subject);
                        } else {
                          _selectedSubjects.remove(subject);
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
