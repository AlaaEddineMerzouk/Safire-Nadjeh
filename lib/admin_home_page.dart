import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:privateecole/pages/attendance_page.dart';
import 'package:privateecole/pages/manage_students_page.dart';
import 'package:privateecole/pages/manage_subjects_page.dart';
import 'package:privateecole/pages/manage_groups_page.dart';
import 'package:privateecole/pages/expenses_page.dart';
import 'package:privateecole/pages/notification_page.dart';
import 'package:privateecole/pages/settings_page.dart';
import 'package:privateecole/pages/statistics_page.dart';
import 'package:privateecole/pages/subscriptions_page.dart';
import 'package:privateecole/pages/teachers_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:privateecole/notification_service.dart';
import 'firebase_options.dart';

// Create a global instance of the notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class AppColors {
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryOrange = Color(0xFFFF8A00);
  static const Color purple = Color(0xFF7C4DFF);
  static const Color red = Colors.redAccent;
  static const Color green = Color(0xFF4CAF50);
  static const Color background = Color(0xFFF7FAFF);
  static const Color backgroundLight = Colors.white;
  static const Color cardBackground = Color(0xFFE3F2FD);
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize the local notifications plugin
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Private École Admin',
      theme: base.copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.primaryBlue,
          secondary: AppColors.primaryOrange,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const AdminShell(),
    );
  }
}

// ===== SHELL WITH ADAPTIVE NAVIGATION =====
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.checkAndUpdateNotifications();
  }

  void _goTo(int i) => setState(() => _index = i);

  late final _allPages = <_AppPage>[
    _AppPage(
        label: 'Dashboard',
        icon: Icons.dashboard_customize_rounded,
        widget: DashboardPage(onGoToTab: _goTo)),
    _AppPage(
        label: 'Subscriptions',
        icon: Icons.receipt_long_rounded,
        widget: const SubscriptionsPage()),
    const _AppPage(
        label: 'Attendance',
        icon: Icons.event_available_rounded,
        widget: AttendancePage()),
    _AppPage(
        label: 'Notifications',
        icon: Icons.notifications_rounded,
        widget: const NotificationsPage()),
    _AppPage(
        label: 'Settings',
        icon: Icons.settings_rounded,
        widget: const SettingsPage()),
    _AppPage(
        label: 'Expenses',
        icon: Icons.money_off_csred_rounded,
        widget: const ExpensesPage()),
    _AppPage(
        label: 'Teachers',
        icon: Icons.school_rounded,
        widget: const TeachersPage()),
    _AppPage(
        label: 'Groups',
        icon: Icons.group_work_rounded,
        widget: const ManageGroupsPage()),
    _AppPage(
        label: 'Subjects',
        icon: Icons.class_rounded,
        widget: const ManageSubjectsPage()),
    _AppPage(
        label: 'Statistics',
        icon: Icons.insights_rounded,
        widget: const StatisticsPage()),
    _AppPage(
        label: 'Students',
        icon: Icons.person_search_rounded,
        widget: const ManageStudentsPage()),
  ];

  late final _navPages = _allPages.sublist(0, 5);

  late final _bottomNavPages = <_AppPage>[
    _AppPage(
        label: 'Dash',
        icon: Icons.dashboard_customize_rounded,
        widget: DashboardPage(onGoToTab: _goTo)),
    const _AppPage(
        label: 'Subs',
        icon: Icons.receipt_long_rounded,
        widget: SubscriptionsPage()),
    const _AppPage(
        label: 'Att',
        icon: Icons.event_available_rounded,
        widget: AttendancePage()),
    const _AppPage(
        label: 'Not',
        icon: Icons.notifications_rounded,
        widget: NotificationsPage()),
    const _AppPage(
        label: 'Set', icon: Icons.settings_rounded, widget: SettingsPage()),
  ];

  Widget _buildNotificationBadge() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _goTo(3),
          );
        }
        final count = snapshot.data!.docs.length;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => _goTo(3),
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Container(
                    key: ValueKey<int>(count),
                    padding: const EdgeInsets.all(2), // Smaller padding
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white, width: 1), // Thinner border
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 15, // Smaller min width
                      minHeight: 15, // Smaller min height
                    ),
                    child: Center(
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8, // Smaller font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth >= 1000;
      final int navIndex =
          _navPages.indexWhere((page) => page.label == _allPages[_index].label);
      final String currentTitle = _allPages[_index].label;

      // This is the updated logic to find the correct index for the bottom nav bar.
      // It now correctly matches the icon of the current page to the icon in the bottom nav pages.
      final int bottomNavIndex = _bottomNavPages
          .indexWhere((page) => page.icon == _allPages[_index].icon);

      return Scaffold(
        appBar: AppBar(
          title: Text(currentTitle,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            if (!isWide)
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () {},
              ),
            _buildNotificationBadge(),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          children: [
            if (isWide)
              NavigationRail(
                selectedIndex: navIndex != -1 ? navIndex : 0,
                onDestinationSelected: (i) {
                  final fullIndex = _allPages.indexOf(_navPages[i]);
                  _goTo(fullIndex);
                },
                extended: c.maxWidth >= 1300,
                minWidth: 64,
                backgroundColor: Colors.white,
                selectedIconTheme:
                    const IconThemeData(color: AppColors.primaryBlue),
                selectedLabelTextStyle:
                    const TextStyle(color: AppColors.primaryBlue),
                destinations: _navPages
                    .map((d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.icon),
                          label: Text(d.label),
                        ))
                    .toList(),
              ),
            Expanded(child: _allPages[_index].widget),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: bottomNavIndex != -1 ? bottomNavIndex : 0,
                onDestinationSelected: (i) {
                  _goTo(i);
                },
                destinations: _bottomNavPages.map((d) {
                  if (d.label == 'Not') {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .where('isRead', isEqualTo: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data?.docs.length ?? 0;
                        return NavigationDestination(
                          icon: Stack(
                            children: [
                              Icon(d.icon),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (Widget child,
                                        Animation<double> animation) {
                                      return ScaleTransition(
                                          scale: animation, child: child);
                                    },
                                    child: Container(
                                      key: ValueKey<int>(unreadCount),
                                      padding: const EdgeInsets.all(
                                          2), // Smaller padding
                                      decoration: BoxDecoration(
                                        color: AppColors.red,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.white,
                                            width: 1), // Thinner border
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 15, // Smaller min width
                                        minHeight: 15, // Smaller min height
                                      ),
                                      child: Center(
                                        child: Text(
                                          unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8, // Smaller font size
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          label: d.label,
                        );
                      },
                    );
                  }
                  return NavigationDestination(
                    icon: Icon(d.icon),
                    label: d.label,
                  );
                }).toList(),
              ),
      );
    });
  }
}

// A new class to hold page data: label, icon, and widget
class _AppPage {
  final String label;
  final IconData icon;
  final Widget widget;
  const _AppPage({
    required this.label,
    required this.icon,
    required this.widget,
  });
}

// ===== DASHBOARD PAGE WIDGET =====
// This is the main widget that holds the state.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onGoToTab});
  final ValueChanged<int> onGoToTab;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

/// ===== DASHBOARD PAGE STATE =====
class _DashboardPageState extends State<DashboardPage> {
  Future<Map<String, dynamic>> _fetchDashboardData() async {
    // 1. Get the current month's start and end dates
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    // 2. Query your collections: 'subscriptions' and 'expenses'
    // Count active students from the total number of subscriptions
    final studentsCountSnapshot = await FirebaseFirestore.instance
        .collection('subscriptions')
        .count()
        .get();

    // Fees: Query 'subscriptions' using 'paymentDate' and sum 'price'
    final feesQuery = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('paymentDate', isGreaterThanOrEqualTo: startOfMonth)
        .where('paymentDate', isLessThanOrEqualTo: endOfMonth)
        .get();

    // Expenses: Now correctly query 'expenses' using 'date' and sum 'amount'
    final expensesQuery = FirebaseFirestore.instance
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .get();

    // Use Future.wait to run the financial queries in parallel
    final results = await Future.wait([feesQuery, expensesQuery]);
    final feesDocs = results[0].docs;
    final expensesDocs = results[1].docs;

    // 3. Process the results
    final studentsCount = studentsCountSnapshot.count;
    double feesCollected = 0.0;
    for (var doc in feesDocs) {
      final data = doc.data();
      feesCollected += (data['price'] as num).toDouble();
    }
    double expenses = 0.0;
    for (var doc in expensesDocs) {
      final data = doc.data();
      // Correctly use 'amount' field from the 'expenses' collection
      expenses += (data['amount'] as num).toDouble();
    }
    final netBalance = feesCollected - expenses;

    // 4. Return the combined data
    return {
      'studentsCount': studentsCount,
      'feesCollected': feesCollected,
      'expenses': expenses,
      'netBalance': netBalance,
    };
  }

  @override
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Overview',
              subtitle: 'Key metrics across your private school',
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchDashboardData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text('No data found.'));
                } else {
                  final data = snapshot.data!;
                  final List<_StatData> statData = [
                    _StatData(
                      color: AppColors.primaryBlue,
                      icon: Icons.people_alt_rounded,
                      value: data['studentsCount'].toString(),
                      unit: 'students',
                      title: 'Active Students',
                      trendText: '+12.5%',
                      trendPositive: true,
                    ),
                    _StatData(
                      color: AppColors.primaryOrange,
                      icon: Icons.receipt_long_rounded,
                      value: data['feesCollected'].toString(),
                      unit: 'DZD',
                      title: 'Fees Collected (Month)',
                      trendText: '+8.2%',
                      trendPositive: true,
                    ),
                    _StatData(
                      color: AppColors.red,
                      icon: Icons.money_off_csred_rounded,
                      value: data['expenses'].toString(),
                      unit: 'DZD',
                      title: 'Expenses (Month)',
                      trendText: '+2.1%',
                      trendPositive: false,
                    ),
                    _StatData(
                      color: AppColors.purple,
                      icon: Icons.account_balance_wallet_rounded,
                      value: data['netBalance'].toString(),
                      unit: 'DZD',
                      title: 'Net Balance (Month)',
                      trendText: '+15.3%',
                      trendPositive: true,
                    ),
                  ];
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: statData.length,
                    itemBuilder: (context, index) {
                      final data = statData[index];
                      return _StatCard(
                        color: data.color,
                        icon: data.icon,
                        value: data.value,
                        unit: data.unit,
                        title: data.title,
                        trendText: data.trendText,
                        trendPositive: data.trendPositive,
                      );
                    },
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400.0,
                      mainAxisSpacing: 16.0,
                      crossAxisSpacing: 16.0,
                      mainAxisExtent: 120,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Quick Actions',
              subtitle: 'Jump straight into management screens',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              const spacing = 12.0;
              final threeCols = c.maxWidth >= 1024;
              final twoCols = c.maxWidth >= 680;
              final perRow = threeCols ? 3 : (twoCols ? 2 : 1);
              final cardWidth = (c.maxWidth - spacing * (perRow - 1)) / perRow;
              final actions = <_ActionItem>[
                _ActionItem(
                  label: 'Expenses',
                  icon: Icons.money_off_csred_rounded,
                  color: AppColors.red,
                  goToTabIndex: 5,
                ),
                _ActionItem(
                  label: 'Teachers',
                  icon: Icons.school_rounded,
                  color: AppColors.primaryOrange,
                  goToTabIndex: 6,
                ),
                _ActionItem(
                  label: 'Groups',
                  icon: Icons.group_work_rounded,
                  color: AppColors.purple,
                  goToTabIndex: 7,
                ),
                _ActionItem(
                  label: 'Subjects',
                  icon: Icons.class_rounded,
                  color: AppColors.primaryBlue,
                  goToTabIndex: 8,
                ),
                _ActionItem(
                  label: 'Students',
                  icon: Icons.person_add_rounded,
                  color: AppColors.green,
                  goToTabIndex: 10,
                ),
                _ActionItem(
                  label: 'Statistics',
                  icon: Icons.insights_rounded,
                  color: AppColors.purple,
                  goToTabIndex: 9,
                ),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final a in actions)
                    SizedBox(
                      width: cardWidth,
                      child: _ActionCard(
                        label: a.label,
                        icon: a.icon,
                        color: a.color,
                        onTap: () => widget.onGoToTab(a.goToTabIndex),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatData {
  const _StatData({
    required this.color,
    required this.icon,
    required this.value,
    required this.unit,
    required this.title,
    this.trendText,
    this.trendPositive = true,
  });
  final Color color;
  final IconData icon;
  final String value;
  final String unit;
  final String title;
  final String? trendText;
  final bool trendPositive;
}

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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.unit,
    required this.title,
    this.trendText,
    this.trendPositive = true,
  });
  final Color color;
  final IconData icon;
  final String value;
  final String unit;
  final String title;
  final String? trendText;
  final bool trendPositive;
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
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (trendText != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trendPositive
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trendPositive
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 14,
                          color: trendPositive ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trendText!,
                          style: TextStyle(
                            color: trendPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final int goToTabIndex;
  _ActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.goToTabIndex,
  });
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== PLACEHOLDER PAGES (replace with real content later) =====
class _Placeholder extends StatelessWidget {
  const _Placeholder(
      {required this.emoji, required this.title, required this.bullets});
  final String emoji;
  final String title;
  final List<String> bullets;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  for (final b in bullets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(fontSize: 16, height: 1.4)),
                          Expanded(
                            child: Text(b,
                                style: TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                    color: Colors.grey[800])),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    child: const Text('Coming soon'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
