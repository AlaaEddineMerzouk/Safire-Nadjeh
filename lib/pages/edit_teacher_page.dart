import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';

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
  final _sessionPriceController = TextEditingController();

  String? _selectedSubject;
  late Future<QuerySnapshot> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.teacherData['fullName'] ?? '';
    _sessionPriceController.text =
        (widget.teacherData['sessionPrice'] ?? 0.0).toString();
    _subjectsFuture = FirebaseFirestore.instance.collection('subjects').get();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _sessionPriceController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSubject == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a subject')),
        );
        return;
      }
      try {
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(widget.docId)
            .update({
          'fullName': _fullNameController.text,
          'subject': _selectedSubject,
          'sessionPrice': double.tryParse(_sessionPriceController.text) ?? 0.0,
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher updated successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update teacher: $e')),
        );
      }
    }
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
                FutureBuilder<QuerySnapshot>(
                  future: _subjectsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Text('Error loading subjects.');
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text(
                          'No subjects available. Add one first.');
                    }

                    final subjects = snapshot.data!.docs;
                    final List<String> subjectNames =
                        subjects.map((doc) => doc['name'] as String).toList();

                    // FIX: Conditionally set the dropdown value.
                    // This prevents the exception if the teacher's subject
                    // doesn't exist in the fetched list of subjects.
                    final initialSubject =
                        widget.teacherData['subject'] as String?;
                    if (_selectedSubject == null &&
                        initialSubject != null &&
                        subjectNames.contains(initialSubject)) {
                      _selectedSubject = initialSubject;
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      hint: const Text('Select a Subject'),
                      items: subjectNames.map((subjectName) {
                        return DropdownMenuItem<String>(
                          value: subjectName,
                          child: Text(subjectName),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSubject = newValue;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        labelStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        prefixIcon:
                            const Icon(Icons.class_, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) =>
                          value == null ? 'Please select a subject' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sessionPriceController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Price per Session',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.attach_money,
                        color: AppColors.primary),
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
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        double.tryParse(value) == null) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
