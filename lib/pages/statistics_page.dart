import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// A simple utility class for consistent colors
class AppColors {
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color green = Color(0xFF4CAF50);
  static const Color red = Color(0xFFF44336);
  static const Color primaryOrange = Color(0xFFFF9800);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF9E9E9E);
  static const Color purple = Color(0xFF9C27B0);
}

// ===== STATISTICS PAGE WIDGET =====
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<Map<String, dynamic>> _statisticsDataFuture;

  @override
  void initState() {
    super.initState();
    _statisticsDataFuture = _fetchStatisticsData();
  }

  // Helper method to get the start and end of a given month
  Map<String, DateTime> _getMonthDates(int monthOffset) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month + monthOffset, 1);
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    return {'start': start, 'end': end};
  }

  Future<Map<String, dynamic>> _fetchStatisticsData() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Get the current month's totals
    final currentMonthFeesQuery = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('paymentDate', isGreaterThanOrEqualTo: startOfMonth)
        .where('paymentDate', isLessThanOrEqualTo: endOfMonth)
        .get();

    final currentMonthExpensesQuery = FirebaseFirestore.instance
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .get();

    final teachersQuery =
        FirebaseFirestore.instance.collection('teachers').get();

    // Get subscription status counts
    final activeCountFuture = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('status', isEqualTo: 'Active')
        .count()
        .get();
    final expiredCountFuture = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('status', isEqualTo: 'Expired')
        .count()
        .get();
    final unknownCountFuture = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('status', isEqualTo: 'Unknown')
        .count()
        .get();

    // NEW: Get the most absent students for the current month
    final attendanceQuery = await FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .where('status', isEqualTo: 'Absent')
        .get();

    Map<String, int> absentCounts = {};
    for (var doc in attendanceQuery.docs) {
      final data = doc.data();
      final studentName = data['studentName'];
      absentCounts[studentName] = (absentCounts[studentName] ?? 0) + 1;
    }

    final topAbsentStudents = absentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Create the final list of absent students with their names and counts
    List<Map<String, dynamic>> mostAbsentStudents = [];
    for (var entry in topAbsentStudents.take(5)) {
      mostAbsentStudents.add({
        'name': entry.key,
        'absences': entry.value,
      });
    }

    // Get historical data for the last 12 months
    Map<String, double> monthlyFees = {};
    Map<String, double> monthlyExpenses = {};
    Map<String, double> monthlyTeacherEarnings = {};
    Map<String, double> monthlyNetRevenue = {};

    for (int i = 11; i >= 0; i--) {
      final monthDates = _getMonthDates(-i);
      final monthName = DateFormat.MMM().format(monthDates['start']!);

      final feesSnapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('paymentDate', isGreaterThanOrEqualTo: monthDates['start'])
          .where('paymentDate', isLessThanOrEqualTo: monthDates['end'])
          .get();
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: monthDates['start'])
          .where('date', isLessThanOrEqualTo: monthDates['end'])
          .get();
      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .where('totalSessions',
              isGreaterThan: 0) // Example to filter for relevant teachers
          .get();

      double fees = feesSnapshot.docs.fold(
          0.0,
          (sum, doc) =>
              sum +
              ((doc.data() as Map<String, dynamic>?)?['price'] as num? ?? 0.0));
      double expense = expensesSnapshot.docs.fold(
          0.0,
          (sum, doc) =>
              sum +
              ((doc.data() as Map<String, dynamic>?)?['amount'] as num? ??
                  0.0));
      double teacherEarnings = teachersSnapshot.docs.fold(
          0.0,
          (sum, doc) =>
              sum +
              ((doc.data() as Map<String, dynamic>?)?['totalEarnings']
                      as num? ??
                  0.0));

      monthlyFees[monthName] = fees;
      monthlyExpenses[monthName] = expense;
      monthlyTeacherEarnings[monthName] = teacherEarnings;
      monthlyNetRevenue[monthName] = fees - expense - teacherEarnings;
    }

    final results = await Future.wait([
      currentMonthFeesQuery,
      currentMonthExpensesQuery,
      teachersQuery,
      activeCountFuture,
      expiredCountFuture,
      unknownCountFuture,
    ]);

    final currentFeesDocs = (results[0] as QuerySnapshot).docs;
    final currentExpensesDocs = (results[1] as QuerySnapshot).docs;
    final teachersDocs = (results[2] as QuerySnapshot).docs;

    double currentMonthFees = currentFeesDocs.fold(
        0.0,
        (sum, doc) =>
            sum +
            ((doc.data() as Map<String, dynamic>?)?['price'] as num? ?? 0.0));
    double currentMonthExpenses = currentExpensesDocs.fold(
        0.0,
        (sum, doc) =>
            sum +
            ((doc.data() as Map<String, dynamic>?)?['amount'] as num? ?? 0.0));
    double totalTeacherEarnings = teachersDocs.fold(
        0.0,
        (sum, doc) =>
            sum +
            ((doc.data() as Map<String, dynamic>?)?['totalEarnings'] as num? ??
                0.0));

    double currentMonthNetRevenue =
        currentMonthFees - currentMonthExpenses - totalTeacherEarnings;

    final activeCount = (results[3] as AggregateQuerySnapshot).count ?? 0;
    final expiredCount = (results[4] as AggregateQuerySnapshot).count ?? 0;
    final unknownCount = (results[5] as AggregateQuerySnapshot).count ?? 0;

    return {
      'currentMonthFees': currentMonthFees,
      'currentMonthExpenses': currentMonthExpenses,
      'totalTeacherEarnings': totalTeacherEarnings,
      'currentMonthNetRevenue': currentMonthNetRevenue,
      'monthlyFees': monthlyFees,
      'monthlyExpenses': monthlyExpenses,
      'monthlyTeacherEarnings': monthlyTeacherEarnings,
      'monthlyNetRevenue': monthlyNetRevenue,
      'subscriptionStatuses': {
        'Active': activeCount,
        'Expired': expiredCount,
        'Unknown': unknownCount,
      },
      'mostAbsentStudents': mostAbsentStudents,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statisticsDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('No data found.'));
            } else {
              final data = snapshot.data!;
              final monthlyFees = data['monthlyFees'] as Map<String, double>;
              final monthlyExpenses =
                  data['monthlyExpenses'] as Map<String, double>;
              final monthlyTeacherEarnings =
                  data['monthlyTeacherEarnings'] as Map<String, double>;
              final monthlyNetRevenue =
                  data['monthlyNetRevenue'] as Map<String, double>;
              final subscriptionStatuses =
                  data['subscriptionStatuses'] as Map<String, int>;
              final mostAbsentStudents =
                  data['mostAbsentStudents'] as List<Map<String, dynamic>>;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    title: 'Statistics & Analytics',
                    subtitle: 'Detailed financial and academic insights',
                  ),
                  const SizedBox(height: 16),

                  // Current Month Financial Overview
                  _SectionHeader(
                    title: 'Financial Overview',
                    subtitle:
                        'Current Month: ${DateFormat.MMMM().format(DateTime.now())}',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CurrentMonthStatCard(
                          title: 'Total Revenue',
                          value:
                              '${data['currentMonthFees'].toStringAsFixed(2)} DZD',
                          icon: Icons.paid_rounded,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CurrentMonthStatCard(
                          title: 'Total Expenses',
                          value:
                              '${data['currentMonthExpenses'].toStringAsFixed(2)} DZD',
                          icon: Icons.money_off_rounded,
                          color: AppColors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CurrentMonthStatCard(
                    title: 'Total Teacher Earnings',
                    value:
                        '${data['totalTeacherEarnings'].toStringAsFixed(2)} DZD',
                    icon: Icons.school_rounded,
                    color: AppColors.primaryOrange,
                  ),
                  const SizedBox(height: 16),
                  _CurrentMonthStatCard(
                    title: 'Net Revenue',
                    value:
                        '${data['currentMonthNetRevenue'].toStringAsFixed(2)} DZD',
                    icon: Icons.show_chart_rounded,
                    color: AppColors.purple,
                  ),

                  const SizedBox(height: 24),

                  // Historical Financial Chart
                  _FinancialChartCard(
                    title: 'Monthly Financials (Last 12 Months)',
                    feesData: monthlyFees,
                    expensesData: monthlyExpenses,
                    teacherEarningsData: monthlyTeacherEarnings,
                    netRevenueData: monthlyNetRevenue,
                  ),

                  const SizedBox(height: 24),

                  // Student Analytics Section
                  const _SectionHeader(
                    title: 'Student Analytics',
                    subtitle: 'Subscription & attendance overview',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SubscriptionStatusCard(
                          title: 'Subscription Status',
                          statusData: subscriptionStatuses,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MostAbsentStudentsCard(
                          title: 'Most Absents this Month',
                          absentStudents: mostAbsentStudents,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

// Reusable header widget
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
      ]),
    );
  }
}

// Reusable card for a single current month stat
class _CurrentMonthStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _CurrentMonthStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable card for financial charts
class _FinancialChartCard extends StatelessWidget {
  final String title;
  final Map<String, double> feesData;
  final Map<String, double> expensesData;
  final Map<String, double> teacherEarningsData;
  final Map<String, double> netRevenueData;

  const _FinancialChartCard({
    required this.title,
    required this.feesData,
    required this.expensesData,
    required this.teacherEarningsData,
    required this.netRevenueData,
  });

  @override
  Widget build(BuildContext context) {
    List<Color> colors = [
      AppColors.primaryBlue,
      AppColors.red,
      AppColors.primaryOrange,
      AppColors.purple
    ];

    List<LineChartBarData> lineBarsData = [
      LineChartBarData(
        spots: feesData.entries
            .map((e) => FlSpot(
                feesData.keys.toList().indexOf(e.key).toDouble(), e.value))
            .toList(),
        isCurved: true,
        color: colors[0],
        barWidth: 3,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: expensesData.entries
            .map((e) => FlSpot(
                expensesData.keys.toList().indexOf(e.key).toDouble(), e.value))
            .toList(),
        isCurved: true,
        color: colors[1],
        barWidth: 3,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: teacherEarningsData.entries
            .map((e) => FlSpot(
                teacherEarningsData.keys.toList().indexOf(e.key).toDouble(),
                e.value))
            .toList(),
        isCurved: true,
        color: colors[2],
        barWidth: 3,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: netRevenueData.entries
            .map((e) => FlSpot(
                netRevenueData.keys.toList().indexOf(e.key).toDouble(),
                e.value))
            .toList(),
        isCurved: true,
        color: colors[3],
        barWidth: 3,
        dotData: const FlDotData(show: false),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final label = feesData.keys.toList()[value.toInt()];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(label,
                                style: const TextStyle(fontSize: 12)),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: lineBarsData,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: [
                _ChartLegend(color: colors[0], label: 'Revenue'),
                _ChartLegend(color: colors[1], label: 'Expenses'),
                _ChartLegend(color: colors[2], label: 'Teacher Earnings'),
                _ChartLegend(color: colors[3], label: 'Net Revenue'),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// Widget for chart legend
class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

// Subscription Status Card
class _SubscriptionStatusCard extends StatelessWidget {
  final String title;
  final Map<String, int> statusData;

  const _SubscriptionStatusCard({
    required this.title,
    required this.statusData,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = [
      AppColors.green,
      AppColors.red,
      AppColors.darkGray
    ];
    final List<IconData> icons = [
      Icons.check_circle_rounded,
      Icons.cancel_rounded,
      Icons.help_outline_rounded
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            ...statusData.keys.map((key) {
              final index = statusData.keys.toList().indexOf(key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(icons[index], color: colors[index], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        key,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      statusData[key].toString(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// NEW WIDGET for Most Absent Students
class _MostAbsentStudentsCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> absentStudents;

  const _MostAbsentStudentsCard({
    required this.title,
    required this.absentStudents,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            if (absentStudents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No absences recorded this month.',
                    style: TextStyle(color: AppColors.darkGray),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...absentStudents.map((student) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          student['name'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${student['absences']}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.red),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
