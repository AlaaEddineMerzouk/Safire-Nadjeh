// 📁 lib/widgets/teacher_card.dart
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
  final VoidCallback onPay;
  final VoidCallback onTap; // New callback for navigating to history

  const TeacherCard({
    Key? key,
    required this.fullName,
    required this.subject,
    required this.totalSessions,
    required this.totalEarnings,
    required this.onEdit,
    required this.onDelete,
    required this.onRecordSession,
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
        onTap: onTap, // Call the new onTap function to navigate
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Teacher Name and Subject
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onRecordSession,
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            color: AppColors.primaryBlue),
                        tooltip: 'Record Session',
                      ),
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
              // Sessions and Earnings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildMetric('Total Sessions',
                        totalSessions.toString(), Icons.school_rounded),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetric(
                        'Total Earnings',
                        '\$${totalEarnings.toStringAsFixed(2)}',
                        Icons.payments_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Pay Button
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
                      borderRadius: BorderRadius.circular(10),
                    ),
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

  Widget _buildMetric(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
