import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';

class ManageSubjectsPage extends StatefulWidget {
  const ManageSubjectsPage({Key? key}) : super(key: key);

  @override
  State<ManageSubjectsPage> createState() => _ManageSubjectsPageState();
}

class _ManageSubjectsPageState extends State<ManageSubjectsPage> {
  final _searchQueryController = TextEditingController();

  Stream<QuerySnapshot> _getSubjectsStream() {
    return FirebaseFirestore.instance.collection('subjects').snapshots();
  }

  void _showAddEditSubjectDialog({String? docId, String? initialName}) {
    final TextEditingController _nameController =
        TextEditingController(text: initialName);
    final bool isEditing = docId != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: Text(isEditing ? 'Edit Subject' : 'Add New Subject',
              style: const TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Subject Name',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              // Corrected styling for the text field
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
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;

                if (isEditing) {
                  await FirebaseFirestore.instance
                      .collection('subjects')
                      .doc(docId)
                      .update({'name': name});
                } else {
                  await FirebaseFirestore.instance
                      .collection('subjects')
                      .add({'name': name});
                }

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Subject ${isEditing ? 'updated' : 'added'} successfully!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
              ),
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('Are you sure you want to delete this subject?',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('subjects')
                    .doc(docId)
                    .delete();
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Subject deleted successfully!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showAddEditSubjectDialog(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchQueryController,
              decoration: InputDecoration(
                labelText: 'Search Subjects',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
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
              onChanged: (value) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getSubjectsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Something went wrong: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No subjects found.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final subjectName =
                      (doc.data() as Map<String, dynamic>)['name']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                  return subjectName
                      .contains(_searchQueryController.text.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('No subjects match your search.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.class_rounded,
                            color: AppColors.primary),
                        title: Text(data['name'] ?? 'N/A',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: AppColors.primary),
                              onPressed: () => _showAddEditSubjectDialog(
                                docId: doc.id,
                                initialName: data['name'],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: AppColors.red),
                              onPressed: () =>
                                  _showDeleteConfirmation(context, doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
