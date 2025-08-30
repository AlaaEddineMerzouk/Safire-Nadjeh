// 📁 lib/pages/add_teacher_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';

class AddTeacherPage extends StatefulWidget {
  const AddTeacherPage({Key? key}) : super(key: key);

  @override
  State<AddTeacherPage> createState() => _AddTeacherPageState();
}

class _AddTeacherPageState extends State<AddTeacherPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _otherPercentageController = TextEditingController();

  String? _selectedPercentage;
  List<QueryDocumentSnapshot> _allGroups = [];
  List<String> _selectedGroupIds = [];
  List<String> _selectedGroupNames = [];

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    final groupsSnapshot =
        await FirebaseFirestore.instance.collection('groups').get();
    setState(() {
      _allGroups = groupsSnapshot.docs;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _otherPercentageController.dispose();
    super.dispose();
  }

  Future<void> _saveTeacher() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGroupIds.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one group.')),
          );
        }
        return;
      }
      double percentage = 0.0;
      if (_selectedPercentage == 'Other') {
        percentage = double.tryParse(_otherPercentageController.text) ?? 0.0;
      } else {
        percentage = double.tryParse(_selectedPercentage ?? '0') ?? 0.0;
      }

      try {
        await FirebaseFirestore.instance.collection('teachers').add({
          'fullName': _fullNameController.text,
          'groupIds': _selectedGroupIds,
          'percentage': percentage,
          'createdAt': Timestamp.now(),
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Teacher added successfully!'),
                backgroundColor: AppColors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to add teacher: $e'),
                backgroundColor: AppColors.red),
          );
        }
      }
    }
  }

  void _showGroupSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Groups'),
          content: SingleChildScrollView(
            child: ListBody(
              children: _allGroups.map((group) {
                final groupId = group.id;
                final groupName = (group.data()
                    as Map<String, dynamic>)['groupName'] as String?;
                if (groupName == null) return const SizedBox.shrink();
                final isSelected = _selectedGroupIds.contains(groupId);
                return CheckboxListTile(
                  title: Text(groupName),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        if (!_selectedGroupIds.contains(groupId)) {
                          _selectedGroupIds.add(groupId);
                          _selectedGroupNames.add(groupName);
                        }
                      } else {
                        _selectedGroupIds.remove(groupId);
                        _selectedGroupNames.remove(groupName);
                      }
                    });
                    Navigator.of(context).pop();
                    _showGroupSelectionDialog();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Teacher',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.primary),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullNameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon:
                      const Icon(Icons.person, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPercentage,
                hint: const Text('Select a percentage'),
                dropdownColor: AppColors.cardBackground,
                items: ['30', '40', '50', '60', 'Other'].map((perc) {
                  return DropdownMenuItem<String>(
                    value: perc,
                    child: Text('$perc%'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPercentage = newValue;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Percentage',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon:
                      const Icon(Icons.percent, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                validator: (value) =>
                    value == null ? 'Please select a percentage' : null,
              ),
              if (_selectedPercentage == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    controller: _otherPercentageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Enter Custom Percentage',
                      prefixIcon:
                          const Icon(Icons.percent, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showGroupSelectionDialog,
                icon: const Icon(Icons.group_add, color: Colors.white),
                label: const Text('Select Groups',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selected Groups: ${_selectedGroupNames.join(', ')}',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveTeacher,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child:
                    const Text('Save Teacher', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
