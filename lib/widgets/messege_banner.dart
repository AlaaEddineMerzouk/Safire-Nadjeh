import 'package:flutter/material.dart';

class MessageBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const MessageBanner({
    super.key,
    required this.message,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final Color successColor = Colors.green.shade700;
    final Color errorColor = Colors.red.shade700;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSuccess
            ? successColor.withOpacity(0.15)
            : errorColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
        border: Border.all(
          color: isSuccess ? successColor : errorColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? successColor : errorColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSuccess ? successColor : errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
