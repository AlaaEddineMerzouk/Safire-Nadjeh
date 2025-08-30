// 📁 lib/widgets/teacher_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';

class TeacherCard extends StatelessWidget {
  final String fullName;
  final List<String> groupIds;
  final double percentage;
  final double pendingEarnings;
  final int totalStudentsPaidFor;
  final double remainingBalance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPay;
  final VoidCallback onTap;

  const TeacherCard({
    Key? key,
    required this.fullName,
    required this.groupIds,
    required this.percentage,
    required this.pendingEarnings,
    required this.totalStudentsPaidFor,
    required this.remainingBalance,
    required this.onEdit,
    required this.onDelete,
    required this.onPay,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        FutureBuilder<List<String>>(
                          future: _getGroupNames(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                  height: 10,
                                  width: 10,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2));
                            }
                            if (snapshot.hasError) {
                              return const Text('Error loading groups',
                                  style: TextStyle(
                                      color: AppColors.red, fontSize: 12));
                            }
                            final groupNames = snapshot.data ?? [];
                            return Text('Groups: ${groupNames.join(', ')}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic));
                          },
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded,
                            color: AppColors.textSecondary),
                        tooltip: 'Edit Teacher',
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_rounded,
                            color: AppColors.red),
                        tooltip: 'Delete Teacher',
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Percentage: ${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Total Students: $totalStudentsPaidFor',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                        'Pending Earnings: \$${pendingEarnings.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.green)),
                    const SizedBox(height: 4),
                    Text(
                        'Remaining Balance: \$${remainingBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.red)),
                  ],
                ),
              ),
              Center(
                child: ElevatedButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.attach_money_rounded,
                      color: Colors.white),
                  label: const Text('Pay Teacher',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>> _getGroupNames() async {
    if (groupIds.isEmpty) return ['No Groups Assigned'];
    final futures = groupIds.map(
        (id) => FirebaseFirestore.instance.collection('groups').doc(id).get());
    final snapshots = await Future.wait(futures);
    return snapshots
        .map((doc) => (doc.data()?['groupName'] as String?) ?? 'N/A')
        .toList();
  }
}
