// 📁 lib/pages/subscriptions_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:privateecole/constants/app_colors.dart';
import 'package:privateecole/widgets/subscription_card.dart';
import 'package:privateecole/widgets/subscription_filter_bar.dart';
import 'package:privateecole/pages/add_subscription_page.dart';
import 'package:privateecole/pages/edit_subscription_page.dart';
import 'package:privateecole/pages/renew_subscription_page.dart';
import 'package:privateecole/pages/subscription_history_page.dart'; // Import the new page

class SubscriptionsPage extends StatefulWidget {
  final String? initialStatus;

  const SubscriptionsPage({Key? key, this.initialStatus}) : super(key: key);

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  String _searchQuery = '';
  late String
      _filterStatus; // Use 'late' because it will be initialized in initState
  String _sortCriterion = 'Payment Date';
  bool _isDescending = true;

  Map<String, String> _groupsMap = {};

  @override
  void initState() {
    super.initState();
    // Use the initialStatus from the widget if it's not null, otherwise default to 'All'
    _filterStatus = widget.initialStatus ?? 'All';
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    final groupsSnapshot =
        await FirebaseFirestore.instance.collection('groups').get();
    final Map<String, String> groups = {};
    for (var doc in groupsSnapshot.docs) {
      groups[doc.id] = doc.data()['groupName'] as String;
    }

    if (mounted) {
      setState(() {
        _groupsMap = groups;
      });
    }
  }

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

                    // Check if subscription is expiring soon (within 7 days)
                    final isExpiringSoon = endDate != null
                        ? endDate.difference(DateTime.now()).inDays <= 7 &&
                            endDate.difference(DateTime.now()).inDays >= 0
                        : false;

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
                          isExpiringSoon: isExpiringSoon,
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
                          // Conditionally show the renew button by passing null
                          // when the status is not 'Expired'
                          onRenew: data['status'] == 'Expired'
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RenewSubscriptionPage(
                                        subscriptionData: data,
                                        docId: sub.id,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          // Add the onTap handler to navigate to the history page
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubscriptionHistoryPage(
                                  subscriptionDocId: sub.id,
                                  studentName: data['studentName'] ?? 'N/A',
                                ),
                              ),
                            );
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
