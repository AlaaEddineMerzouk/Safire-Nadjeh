// 📁 lib/pages/edit_teacher_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'dart:developer';

class EditTeacherPage extends StatefulWidget {
  final Map<String, dynamic> teacherData;
  final String docId;

  const EditTeacherPage(
      {Key? key, required this.teacherData, required this.docId})
      : super(key: key);

  @override
  State<EditTeacherPage> createState() => _EditTeacherPageState();
}

class _EditTeacherPageState extends State<EditTeacherPage> {
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
    // Initialize controllers and state with existing data
    _fullNameController.text = widget.teacherData['fullName'] as String? ?? '';
    final percentage = (widget.teacherData['percentage'] as num?)?.toInt();
    if (percentage != null && [30, 40, 50, 60].contains(percentage)) {
      _selectedPercentage = percentage.toString();
    } else {
      _selectedPercentage = 'Other';
      _otherPercentageController.text = percentage?.toString() ?? '';
    }

    _fetchGroupsAndSetInitialSelection();
  }

  /// Fetches all groups from Firestore and sets the initial selected groups for the teacher.
  Future<void> _fetchGroupsAndSetInitialSelection() async {
    try {
      final groupsSnapshot =
          await FirebaseFirestore.instance.collection('groups').get();
      setState(() {
        _allGroups = groupsSnapshot.docs;
      });

      // Populate selected groups based on the teacher's existing data
      final List<String> teacherGroupIds = List<String>.from(
          widget.teacherData['groupIds'] as List<dynamic>? ?? []);
      _selectedGroupIds.clear();
      _selectedGroupNames.clear();

      for (var group in _allGroups) {
        if (teacherGroupIds.contains(group.id)) {
          _selectedGroupIds.add(group.id);
          _selectedGroupNames.add(
              (group.data() as Map<String, dynamic>)['groupName'] as String);
        }
      }
      log('Fetched ${_allGroups.length} groups and set initial selection.');
    } catch (e) {
      log('Error fetching groups: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load groups: $e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _otherPercentageController.dispose();
    super.dispose();
  }

  /// Validates the form and saves the changes to the teacher's document in Firestore.
  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGroupIds.isEmpty) {
        if (mounted) {
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
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(widget.docId)
            .update({
          'fullName': _fullNameController.text,
          'groupIds': _selectedGroupIds,
          'percentage': percentage,
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Teacher updated successfully!'),
                backgroundColor: AppColors.green),
          );
        }
      } catch (e) {
        log('Error updating teacher: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to update teacher: $e'),
                backgroundColor: AppColors.red),
          );
        }
      }
    }
  }

  /// Shows a dialog for group selection.
  void _showGroupSelectionDialog() {
    final List<String> tempSelectedIds = List.from(_selectedGroupIds);
    final List<String> tempSelectedNames = List.from(_selectedGroupNames);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Select Groups'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: _allGroups.map((group) {
                    final groupId = group.id;
                    final groupName = (group.data()
                        as Map<String, dynamic>)['groupName'] as String?;
                    if (groupName == null) return const SizedBox.shrink();
                    final isSelected = tempSelectedIds.contains(groupId);
                    return CheckboxListTile(
                      title: Text(groupName),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setStateInDialog(() {
                          if (value == true) {
                            if (!tempSelectedIds.contains(groupId)) {
                              tempSelectedIds.add(groupId);
                              tempSelectedNames.add(groupName);
                            }
                          } else {
                            tempSelectedIds.remove(groupId);
                            tempSelectedNames.remove(groupName);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedGroupIds = tempSelectedIds;
                      _selectedGroupNames = tempSelectedNames;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Teacher',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.primary),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
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
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
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
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Changes',
                      style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
