// 📁 lib/widgets/student_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import this for clipboard functionality
import 'package:privateecole/constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

class StudentCard extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String? phone;
  final String? birthday;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StudentCard({
    Key? key,
    required this.studentName,
    required this.studentId,
    this.phone,
    this.birthday,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  // Function to launch the phone dialer
  void _launchPhoneCall(BuildContext context, String phoneNumber) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not launch phone call. The feature may not be supported on this device.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while launching the phone dialer.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // Function to copy text to the clipboard
  void _copyToClipboard(BuildContext context, String textToCopy) {
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Phone number copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $studentId',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (birthday != null && birthday!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      // Birthday with a birthday cake icon
                      Row(
                        children: [
                          const Icon(Icons.cake,
                              color: AppColors.textSecondary, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Birthday: $birthday',
                            style:
                                const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    if (phone != null && phone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      // Phone number with clickable style and copy button
                      InkWell(
                        onTap: () => _launchPhoneCall(context, phone!),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.phone,
                                color: AppColors.textSecondary, size: 16),
                            const SizedBox(width: 8),
                            // Expanded widget prevents the text from overflowing
                            Expanded(
                              child: Text(
                                '$phone',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () =>
                                  _copyToClipboard(context, phone!),
                              icon: const Icon(Icons.copy,
                                  color: AppColors.textSecondary, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.orange),
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
        ),
      ),
    );
  }
}
