// 📁 lib/pages/subscription_history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class SubscriptionHistoryPage extends StatefulWidget {
  final String subscriptionDocId;
  final String studentName;

  const SubscriptionHistoryPage({
    Key? key,
    required this.subscriptionDocId,
    required this.studentName,
  }) : super(key: key);

  @override
  State<SubscriptionHistoryPage> createState() =>
      _SubscriptionHistoryPageState();
}

class _SubscriptionHistoryPageState extends State<SubscriptionHistoryPage> {
  Map<String, dynamic>? _currentSubscriptionData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentSubscription();
  }

  Future<void> _fetchCurrentSubscription() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(widget.subscriptionDocId)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          _currentSubscriptionData = docSnapshot.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching current subscription: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        title: Text(
          '${widget.studentName} History',
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subscriptions')
                  .doc(widget.subscriptionDocId)
                  .collection('renewals')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<DocumentSnapshot> renewals = snapshot.data?.docs ?? [];

                List<Map<String, dynamic>> historyItems = [];
                if (_currentSubscriptionData != null) {
                  historyItems.add(_currentSubscriptionData!);
                }

                historyItems.addAll(
                    renewals.map((doc) => doc.data() as Map<String, dynamic>));

                if (historyItems.isEmpty) {
                  return Center(
                    child: Text(
                      'No history found for this subscription.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 20.0),
                  itemCount: historyItems.length,
                  itemBuilder: (context, index) {
                    final data = historyItems[index];
                    final isCurrentSubscription =
                        index == 0 && _currentSubscriptionData != null;

                    final paymentDate =
                        (data['paymentDate'] as Timestamp?)?.toDate();
                    final endDate = (data['endDate'] as Timestamp?)?.toDate();
                    final firstLessonDate =
                        (data['firstLessonDate'] as Timestamp?)?.toDate();

                    String statusText;
                    Color statusColor;

                    if (endDate == null) {
                      statusText = 'Unknown';
                      statusColor = Colors.grey;
                    } else if (endDate.isBefore(DateTime.now())) {
                      statusText = 'Expired';
                      statusColor = AppColors.red;
                    } else {
                      statusText = 'Active';
                      statusColor = AppColors.green;
                    }

                    return Card(
                      color: AppColors.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 20.0),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isCurrentSubscription
                                      ? 'Current Subscription'
                                      : 'Renewal ${renewals.length - (index - 1)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (isCurrentSubscription)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(
                                height: 24, thickness: 1, color: Colors.grey),
                            _buildInfoRow(
                              icon: Icons.paid_outlined,
                              label: 'Price',
                              value:
                                  '${data['price']?.toStringAsFixed(2) ?? 'N/A'} DZD',
                            ),
                            _buildInfoRow(
                              icon: Icons.event,
                              label: 'Payment Date',
                              value: paymentDate != null
                                  ? DateFormat('dd MMM yyyy')
                                      .format(paymentDate)
                                  : 'N/A',
                            ),
                            _buildInfoRow(
                              icon: Icons.event_note,
                              label: 'First Lesson Date',
                              value: firstLessonDate != null
                                  ? DateFormat('dd MMM yyyy')
                                      .format(firstLessonDate)
                                  : 'N/A',
                            ),
                            _buildInfoRow(
                              icon: Icons.event_busy_outlined,
                              label: 'End Date',
                              value: endDate != null
                                  ? DateFormat('dd MMM yyyy').format(endDate)
                                  : 'N/A',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryOrange),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
