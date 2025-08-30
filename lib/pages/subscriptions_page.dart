// 📁 lib/pages/subscriptions_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:privateecole/constants/app_colors.dart';
import 'package:privateecole/widgets/subscription_card.dart';
import 'package:privateecole/widgets/subscription_filter_bar.dart';
import 'package:privateecole/pages/add_subscription_page.dart';
import 'package:privateecole/pages/edit_subscription_page.dart';
import 'package:privateecole/pages/renew_subscription_page.dart';
import 'package:privateecole/pages/subscription_history_page.dart';

class SubscriptionsPage extends StatefulWidget {
  final String? initialStatus;

  const SubscriptionsPage({Key? key, this.initialStatus}) : super(key: key);

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  String _searchQuery = '';
  late String _filterStatus;
  String _sortCriterion = 'Payment Date';
  bool _isDescending = true;

  Map<String, String> _groupsMap = {};
  Map<String, String> _studentsMap = {};

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialStatus ?? 'All';
    _fetchGroups();
    _fetchStudents();
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

  Future<void> _fetchStudents() async {
    final studentsSnapshot =
        await FirebaseFirestore.instance.collection('students').get();
    final Map<String, String> students = {};
    for (var doc in studentsSnapshot.docs) {
      students[doc.id] = doc.data()['studentName'] as String;
    }

    if (mounted) {
      setState(() {
        _studentsMap = students;
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

    // Sort based on selected criterion for fields that exist on the document.
    // 'Name' and 'Group' are sorted locally.
    if (_sortCriterion == 'Payment Date') {
      query = query.orderBy('paymentDate', descending: _isDescending);
    } else if (_sortCriterion == 'Price') {
      query = query.orderBy('price', descending: _isDescending);
    } else if (_sortCriterion == 'End Date') {
      query = query.orderBy('endDate', descending: _isDescending);
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
                final now = DateTime.now();

                // Local filtering based on search query and calculated status
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentName =
                      _studentsMap[data['studentId']]?.toLowerCase() ?? '';
                  final groupNames = (data['groupIds'] as List<dynamic>?)
                          ?.map((id) => _groupsMap[id]?.toLowerCase() ?? '')
                          .join(' ')
                          .trim() ??
                      '';
                  final endDate = (data['endDate'] as Timestamp?)?.toDate();

                  String calculatedStatus = 'Unknown';
                  if (endDate != null) {
                    if (endDate.isBefore(now)) {
                      calculatedStatus = 'Expired';
                    } else {
                      calculatedStatus = 'Active';
                    }
                  }

                  final matchesSearch =
                      studentName.contains(_searchQuery.toLowerCase()) ||
                          groupNames.contains(_searchQuery.toLowerCase());

                  final matchesFilter = _filterStatus == 'All' ||
                      calculatedStatus == _filterStatus;

                  return matchesSearch && matchesFilter;
                }).toList();

                // Local sorting for 'Group' and 'Name'
                if (_sortCriterion == 'Group') {
                  filteredDocs.sort((a, b) {
                    final groupIdsA =
                        (a.data() as Map<String, dynamic>)['groupIds']
                                as List<dynamic>? ??
                            [];
                    final groupNamesA =
                        groupIdsA.map((id) => _groupsMap[id] ?? '').join(' ');
                    final groupIdsB =
                        (b.data() as Map<String, dynamic>)['groupIds']
                                as List<dynamic>? ??
                            [];
                    final groupNamesB =
                        groupIdsB.map((id) => _groupsMap[id] ?? '').join(' ');
                    return _isDescending
                        ? groupNamesB.compareTo(groupNamesA)
                        : groupNamesA.compareTo(groupNamesB);
                  });
                } else if (_sortCriterion == 'Name') {
                  filteredDocs.sort((a, b) {
                    final studentNameA = _studentsMap[
                            (a.data() as Map<String, dynamic>)['studentId']] ??
                        '';
                    final studentNameB = _studentsMap[
                            (b.data() as Map<String, dynamic>)['studentId']] ??
                        '';
                    return _isDescending
                        ? studentNameB.compareTo(studentNameA)
                        : studentNameA.compareTo(studentNameB);
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
                    final now = DateTime.now();

                    String calculatedStatus = 'Unknown';
                    if (endDate != null) {
                      if (endDate.isBefore(now)) {
                        calculatedStatus = 'Expired';
                      } else {
                        calculatedStatus = 'Active';
                      }
                    }

                    // Get group names from group IDs
                    final groupIds = data['groupIds'] as List<dynamic>? ?? [];
                    final groupNames = groupIds
                        .map((id) => _groupsMap[id] ?? 'N/A')
                        .join(', ');

                    return FutureBuilder<bool>(
                      future: calculatedStatus == 'Expired'
                          ? _hasPresentAfterExpired(data['studentId'], endDate!)
                          : Future.value(false),
                      builder: (context, snapshot) {
                        final hasPresentAfterExpired = snapshot.data ?? false;

                        return SubscriptionCard(
                          studentId: data['studentId'],
                          price: (data['price'] ?? 0).toDouble(),
                          status: calculatedStatus,
                          paymentDate:
                              (data['paymentDate'] as Timestamp?)?.toDate(),
                          endDate: endDate,
                          group: groupNames,
                          hasExpired: calculatedStatus == 'Expired',
                          hasPresentAfterExpired: hasPresentAfterExpired,
                          isExpiringSoon:
                              false, // Set to false since it's not a displayed status
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
                          onRenew: calculatedStatus == 'Expired'
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
                          onTap: () {
                            final studentName =
                                _studentsMap[data['studentId']] ?? 'N/A';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubscriptionHistoryPage(
                                  subscriptionDocId: sub.id,
                                  studentName: studentName,
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
