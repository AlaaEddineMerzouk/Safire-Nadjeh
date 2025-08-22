// 📁 lib/pages/subscriptions_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:privateecole/constants/app_colors.dart';
import 'package:privateecole/widgets/subscription_card.dart';
import 'package:privateecole/widgets/subscription_filter_bar.dart';
import 'package:privateecole/pages/add_subscription_page.dart';
import 'package:privateecole/pages/edit_subscription_page.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({Key? key}) : super(key: key);

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _sortCriterion = 'Payment Date';
  bool _isDescending = true;

  Map<String, String> _groupsMap = {};

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    final groupsSnapshot =
        await FirebaseFirestore.instance.collection('groups').get();
    final Map<String, String> groups = {};
    for (var doc in groupsSnapshot.docs) {
      groups[doc.id] = doc.data()['groupName'] as String;
    }

    // The fix: check if the widget is still in the tree before setting state
    if (mounted) {
      setState(() {
        _groupsMap = groups;
      });
    }
  }

  // This is the new function to check for attendance after expiration
  Future<bool> _hasPresentAfterExpired(
      String studentId, DateTime endDate) async {
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'Present')
        .where('date', isGreaterThan: endDate)
        .limit(1) // We only need to find one document to confirm
        .get();

    return attendanceSnapshot.docs.isNotEmpty;
  }

  Stream<QuerySnapshot> _getSubscriptionsStream() {
    Query query = FirebaseFirestore.instance.collection('subscriptions');

    if (_filterStatus != 'All') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    if (_sortCriterion == 'Payment Date') {
      query = query.orderBy('paymentDate', descending: _isDescending);
    } else if (_sortCriterion == 'Price') {
      query = query.orderBy('price', descending: _isDescending);
    } else if (_sortCriterion == 'Name') {
      query = query.orderBy('studentName', descending: _isDescending);
    } else if (_sortCriterion == 'End Date') {
      query = query.orderBy('endDate', descending: _isDescending);
    } else if (_sortCriterion == 'Group') {
      // Local sorting is handled after fetching the data
    }

    return query.snapshots();
  }

  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text(
            'Confirm Deletion',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Are you sure you want to delete this subscription?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .doc(docId)
                    .delete();
                if (mounted) {
                  Navigator.of(context).pop();
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
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AddSubscriptionPage()),
          );
        },
      ),
      body: Column(
        children: [
          SubscriptionFilterBar(
            searchQuery: _searchQuery,
            filterStatus: _filterStatus,
            sortCriterion: _sortCriterion,
            isDescending: _isDescending,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            onFilterChanged: (value) => setState(() => _filterStatus = value),
            onSortCriterionChanged: (value) =>
                setState(() => _sortCriterion = value),
            onSortDirectionChanged: () =>
                setState(() => _isDescending = !_isDescending),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getSubscriptionsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No subscriptions found.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  );
                }

                final allDocs = snapshot.data!.docs;

                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentName =
                      data['studentName']?.toString().toLowerCase() ?? '';
                  final groupName =
                      _groupsMap[data['groupId']]?.toLowerCase() ?? '';
                  return studentName.contains(_searchQuery.toLowerCase()) ||
                      groupName.contains(_searchQuery.toLowerCase());
                }).toList();

                if (_sortCriterion == 'Group') {
                  filteredDocs.sort((a, b) {
                    final groupNameA = _groupsMap[
                            (a.data() as Map<String, dynamic>)['groupId']] ??
                        '';
                    final groupNameB = _groupsMap[
                            (b.data() as Map<String, dynamic>)['groupId']] ??
                        '';
                    return _isDescending
                        ? groupNameB.compareTo(groupNameA)
                        : groupNameA.compareTo(groupNameB);
                  });
                }

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'No subscriptions match your search.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final sub = filteredDocs[index];
                    final data = sub.data() as Map<String, dynamic>;

                    final endDate = (data['endDate'] as Timestamp?)?.toDate();
                    final hasExpired = endDate != null
                        ? endDate.isBefore(DateTime.now())
                        : false;

                    // Use a FutureBuilder to handle the async check
                    return FutureBuilder<bool>(
                      future: hasExpired
                          ? _hasPresentAfterExpired(data['studentId'], endDate!)
                          : Future.value(false),
                      builder: (context, snapshot) {
                        final hasPresentAfterExpired = snapshot.data ?? false;

                        return SubscriptionCard(
                          studentName: data['studentName'] ?? '',
                          price: (data['price'] ?? 0).toDouble(),
                          status: data['status'] ?? 'Unknown',
                          paymentDate:
                              (data['paymentDate'] as Timestamp?)?.toDate(),
                          endDate: endDate,
                          group: _groupsMap[data['groupId']] ?? 'N/A',
                          hasExpired: hasExpired,
                          hasPresentAfterExpired: hasPresentAfterExpired,
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditSubscriptionPage(
                                  subscriptionData: data,
                                  docId: sub.id,
                                ),
                              ),
                            );
                          },
                          onDelete: () {
                            _showDeleteConfirmation(context, sub.id);
                          },
                        );
                      },
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
