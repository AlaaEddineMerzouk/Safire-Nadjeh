import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class ExpenseCard extends StatelessWidget {
  final String name;
  final double amount;
  final String status;
  final DateTime date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const ExpenseCard({
    Key? key,
    required this.name,
    required this.amount,
    required this.status,
    required this.date,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'Paid' ? Colors.green : AppColors.red;
    final statusIcon =
        status == 'Paid' ? Icons.check_circle : Icons.warning_rounded;

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
                    name,
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
                      icon: const Icon(Icons.edit, color: AppColors.blue),
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
            Text(
              'Amount: \$${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppColors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(date)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Status: ',
                    style: const TextStyle(color: AppColors.textSecondary)),
                Text(status,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onToggleStatus,
                icon: Icon(statusIcon, color: AppColors.textOnPrimary),
                label: Text(
                  status == 'Paid' ? 'Mark as Unpaid' : 'Mark as Paid',
                  style: const TextStyle(color: AppColors.textOnPrimary),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
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
