import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Placeholder for AppColors to make the file runnable as a standalone example ---
class AppColors {
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryOrange = Color(0xFFFF8A00);
  static const Color purple = Color(0xFF7C4DFF);
  static const Color red = Colors.redAccent;
  static const Color green = Color(0xFF4CAF50);
  static const Color background = Color(0xFFF0F4F8);
  static const Color backgroundLight = Colors.white;
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textOnPrimary = Colors.white;
  static const Color orange = Colors.deepOrange;
}
// ----------------------------------------------------------------------------------

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  // Optimized function to calculate total revenue from subscriptions and renewals
  Future<double> _calculateTotalRevenue() async {
    double totalRevenue = 0.0;
    try {
      final subscriptionsSnapshot =
          await FirebaseFirestore.instance.collection('subscriptions').get();
      for (var subscriptionDoc in subscriptionsSnapshot.docs) {
        final data = subscriptionDoc.data();
        if (data.containsKey('price')) {
          totalRevenue += (data['price'] as num).toDouble();
        }
      }

      final renewalsSnapshot =
          await FirebaseFirestore.instance.collectionGroup('renewals').get();
      for (var renewalDoc in renewalsSnapshot.docs) {
        final renewalData = renewalDoc.data();
        if (renewalData.containsKey('price')) {
          totalRevenue += (renewalData['price'] as num).toDouble();
        }
      }
    } catch (e) {
      print("Error fetching total revenue: $e");
    }
    return totalRevenue;
  }

  // Asynchronous function to calculate total earnings from teachers
  Future<double> _calculateTotalTeacherEarnings() async {
    double totalTeacherEarnings = 0.0;
    try {
      final paymentsSnapshot =
          await FirebaseFirestore.instance.collection('teacher_payments').get();

      for (var paymentDoc in paymentsSnapshot.docs) {
        final data = paymentDoc.data();
        if (data.containsKey('paidAmount')) {
          totalTeacherEarnings += (data['paidAmount'] as num).toDouble();
        }
      }
    } catch (e) {
      print("Error fetching total teacher earnings: $e");
    }
    return totalTeacherEarnings;
  }

  // Asynchronous function to calculate total expenses.
  Future<double> _calculateTotalExpenses() async {
    double totalExpenses = 0.0;
    try {
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('status', isEqualTo: 'Paid')
          .get();

      for (var expenseDoc in expensesSnapshot.docs) {
        final data = expenseDoc.data();
        if (data.containsKey('amount')) {
          totalExpenses += (data['amount'] as num).toDouble();
        }
      }
    } catch (e) {
      print("Error fetching total expenses: $e");
    }
    return totalExpenses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Page Header ---
              const _PageHeader(
                title: 'Membership Statistics',
                subtitle:
                    'A concise and scalable overview of your subscriptions.',
              ),
              const SizedBox(height: 24.0),

              // --- Subscription Status Section ---
              const _SectionTitle(title: 'Live Subscription Status'),
              const SizedBox(height: 16.0),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subscriptions')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No subscription data found.'));
                  }

                  final documents = snapshot.data!.docs;
                  int activeCount = 0;
                  int expiredCount = 0;
                  int unknownCount = 0; // Correctly initialize and use this
                  final int totalMembers = documents.length;
                  final now = DateTime.now();

                  // CORRECTED: Calculate status dynamically based on endDate
                  for (var doc in documents) {
                    final data = doc.data() as Map<String, dynamic>;
                    final endDate = (data['endDate'] as Timestamp?)?.toDate();

                    if (endDate == null) {
                      unknownCount++;
                    } else if (endDate.isAfter(now)) {
                      activeCount++;
                    } else {
                      expiredCount++;
                    }
                  }

                  return Column(
                    children: [
                      SizedBox(
                        height: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _CompactMetricCard(
                                title: 'Total subscriptions',
                                value: totalMembers.toString(),
                                icon: Icons.group_rounded,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: _CompactMetricCard(
                                title: 'Active',
                                value: activeCount.toString(),
                                icon: Icons.check_circle_outline_rounded,
                                color: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        height: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _CompactMetricCard(
                                title: 'Expired',
                                value: expiredCount.toString(),
                                icon: Icons.cancel_outlined,
                                color: AppColors.red,
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: _CompactMetricCard(
                                title: 'Unknown',
                                value: unknownCount.toString(),
                                icon: Icons.help_outline_rounded,
                                color: AppColors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24.0),

              // --- Financial Overview Section ---
              const _SectionTitle(title: 'Financial Overview'),
              const SizedBox(height: 16.0),

              FutureBuilder<List<double>>(
                future: Future.wait([
                  _calculateTotalRevenue(),
                  _calculateTotalTeacherEarnings(),
                  _calculateTotalExpenses(),
                ]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print(snapshot.error);
                    return const _CompactMetricCard(
                      title: 'Data Error',
                      value: 'Error',
                      icon: Icons.error_outline,
                      color: AppColors.red,
                    );
                  }

                  final totalRevenue = snapshot.data![0];
                  final totalTeacherEarnings = snapshot.data![1];
                  final totalExpenses = snapshot.data![2];

                  final netProfit =
                      totalRevenue - totalTeacherEarnings - totalExpenses;

                  return Column(
                    children: [
                      _CompactMetricCard(
                        title: 'Total Revenue',
                        value: '\$ ${totalRevenue.toStringAsFixed(2)}',
                        icon: Icons.monetization_on_rounded,
                        color: AppColors.primaryOrange,
                      ),
                      const SizedBox(height: 16.0),
                      _CompactMetricCard(
                        title: 'Total Expenses',
                        value: '\$ ${totalExpenses.toStringAsFixed(2)}',
                        icon: Icons.payment_rounded,
                        color: AppColors.red,
                      ),
                      const SizedBox(height: 16.0),
                      _CompactMetricCard(
                        title: 'Total Earnings Paid to Teachers',
                        value: '\$ ${totalTeacherEarnings.toStringAsFixed(2)}',
                        icon: Icons.attach_money_rounded,
                        color: AppColors.purple,
                      ),
                      const SizedBox(height: 16.0),
                      _CompactMetricCard(
                        title: 'Net Profit',
                        value: '\$ ${netProfit.toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppColors.green,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A new, very compact card with a professional, minimalist look
class _CompactMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactMetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable widget for the page header
class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageHeader({
    Key? key,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// Reusable widget for section titles
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
