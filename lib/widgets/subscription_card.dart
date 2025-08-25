// 📁 lib/widgets/subscription_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class SubscriptionCard extends StatelessWidget {
  final String studentName;
  final double price;
  final String status;
  final DateTime? paymentDate;
  final DateTime? endDate;
  final String group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // New fields to be passed from the parent widget
  final bool hasExpired;
  final bool hasPresentAfterExpired;
  final bool isExpiringSoon;
  final VoidCallback? onRenew; // Made optional
  final VoidCallback onTap;

  const SubscriptionCard({
    Key? key,
    required this.studentName,
    required this.price,
    required this.status,
    required this.paymentDate,
    required this.endDate,
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.hasExpired,
    required this.hasPresentAfterExpired,
    required this.isExpiringSoon,
    this.onRenew, // No longer required
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final statusColor = status == 'Active' ? AppColors.green : AppColors.red;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      studentName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasExpired) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hasPresentAfterExpired) ...[
                      const Icon(Icons.warning,
                          color: AppColors.orange, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Attended after expiration',
                        style: TextStyle(color: AppColors.orange, fontSize: 14),
                      ),
                    ] else ...[
                      const Icon(Icons.info, color: AppColors.red, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Subscription expired',
                        style: TextStyle(color: AppColors.red, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoColumn(
                    icon: Icons.attach_money,
                    label: 'Price',
                    value: '\$${price.toStringAsFixed(2)}',
                  ),
                  _buildInfoColumn(
                    icon: Icons.group,
                    label: 'Group',
                    value: group,
                  ),
                  _buildInfoColumn(
                    icon: Icons.calendar_month,
                    label: 'Paid',
                    value: paymentDate != null
                        ? dateFormat.format(paymentDate!)
                        : 'N/A',
                  ),
                  _buildInfoColumn(
                    icon: Icons.event_busy,
                    label: 'Ends',
                    value:
                        endDate != null ? dateFormat.format(endDate!) : 'N/A',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Conditionally show the Renew button only if onRenew is not null
                  if (onRenew != null)
                    IconButton(
                      icon: const Icon(Icons.autorenew, color: AppColors.green),
                      onPressed: onRenew,
                      tooltip: 'Renew Subscription',
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.orange),
                    onPressed: onEdit,
                    tooltip: 'Edit Subscription',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.red),
                    onPressed: onDelete,
                    tooltip: 'Delete Subscription',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
