import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TeacherCard extends StatelessWidget {
  final String fullName;
  final String subject;
  final int totalSessions;
  final double totalEarnings;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRecordSession;

  const TeacherCard({
    Key? key,
    required this.fullName,
    required this.subject,
    required this.totalSessions,
    required this.totalEarnings,
    required this.onEdit,
    required this.onDelete,
    required this.onRecordSession,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.cardBackground,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.red),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Subject: $subject',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Total Sessions: $totalSessions',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              'Total Earnings: \$${totalEarnings.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppColors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRecordSession,
                icon: const Icon(Icons.add_circle_outline,
                    color: AppColors.textOnPrimary),
                label: const Text('Record Session',
                    style: TextStyle(color: AppColors.textOnPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
