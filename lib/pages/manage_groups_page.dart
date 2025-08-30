// 📁 lib/pages/manage_groups_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'add_group_page.dart';
import 'edit_group_page.dart';

class ManageGroupsPage extends StatefulWidget {
  const ManageGroupsPage({Key? key}) : super(key: key);

  @override
  State<ManageGroupsPage> createState() => _ManageGroupsPageState();
}

class _ManageGroupsPageState extends State<ManageGroupsPage> {
  String _searchQuery = '';

  Stream<QuerySnapshot> _getGroupsStream() {
    return FirebaseFirestore.instance.collection('groups').snapshots();
  }

  void _showDeleteConfirmation(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
              'Are you sure you want to delete this group? All associated subscriptions will also be deleted.',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                // Dismiss the AlertDialog first
                Navigator.of(dialogContext).pop();

                try {
                  final subscriptionsSnapshot = await FirebaseFirestore.instance
                      .collection('subscriptions')
                      .where('groupId', isEqualTo: groupId)
                      .get();

                  final batch = FirebaseFirestore.instance.batch();

                  for (var doc in subscriptionsSnapshot.docs) {
                    batch.delete(doc.reference);
                  }

                  batch.delete(FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupId));

                  await batch.commit();

                  // Safely show the SnackBar using the main page's context
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Group and subscriptions deleted successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete group: $e')),
                    );
                  }
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddGroupPage()),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Groups',
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
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getGroupsStream(),
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
                    child: Text('No groups found.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final groupName =
                      (doc.data() as Map<String, dynamic>)['groupName']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                  return groupName.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('No groups match your search.',
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

                    final teacherId = data['teacherId'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.group_work_rounded,
                            color: AppColors.primary),
                        title: Text(data['groupName'] ?? 'N/A',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: teacherId != null && teacherId.isNotEmpty
                            ? FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('teachers')
                                    .doc(teacherId)
                                    .get(),
                                builder: (context, teacherSnapshot) {
                                  if (teacherSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Text('Loading teacher...',
                                        style: TextStyle(
                                            color: AppColors.textSecondary));
                                  }
                                  if (teacherSnapshot.hasData &&
                                      teacherSnapshot.data!.exists) {
                                    final teacherName = teacherSnapshot
                                            .data!['fullName'] as String? ??
                                        'Unknown Teacher';
                                    return Text('Teacher: $teacherName');
                                  }
                                  return const Text('Teacher: Unknown');
                                },
                              )
                            : const Text('Teacher: Not Assigned'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: AppColors.primary),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditGroupPage(
                                      groupId: doc.id,
                                      initialData: data,
                                    ),
                                  ),
                                );
                              },
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
