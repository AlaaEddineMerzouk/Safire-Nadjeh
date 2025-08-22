// 📁 lib/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:privateecole/notification_service.dart';
import 'package:privateecole/constants/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _notificationService.checkAndUpdateNotifications();
  }

  // Method to show a confirmation dialog for deleting a single notification
  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, DocumentReference docRef) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Are you sure you want to delete this notification?',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await docRef.delete();
                if (!mounted) return;
                // FIX: Use the main page's context (`this.context`) which is guaranteed to be valid,
                // not the temporary context from the dialog (`dialogContext`).
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Notification deleted')),
                );
                // Use the dialog's context to pop itself.
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // New method to show a confirmation dialog for deleting all notifications
  Future<void> _showDeleteAllConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Are you sure you want to delete all notifications?',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _notificationService.deleteAllNotifications();
                if (!mounted) return;
                // FIX: Use the main page's context (`this.context`).
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('All notifications deleted')),
                );
                // Use the dialog's context to pop itself.
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 1, // Start on the 'Unread' tab
      length: 2,
      child: Column(
        children: [
          // Action buttons for all notifications
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _notificationService.markAllAsRead(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Mark All as Read',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showDeleteAllConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Delete All',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // TabBar consistent with app theme
          Container(
            color: AppColors.background,
            child: TabBar(
              indicatorColor: AppColors.primaryBlue,
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 4.0,
              tabs: [
                const Tab(text: 'All Notifications'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Unread'),
                      const SizedBox(width: 8),
                      if (_unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            _unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: All Notifications
                _buildNotificationList(
                    query: FirebaseFirestore.instance
                        .collection('notifications')
                        .orderBy('timestamp', descending: true)),
                // Tab 2: Unread Notifications
                _buildNotificationList(
                    query: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('isRead', isEqualTo: false)
                        .orderBy('timestamp', descending: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList({required Query query}) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (query.parameters.containsKey('isRead')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _unreadCount = 0);
            });
          }
          return Center(
            child: Text(
              'No notifications found.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          );
        }

        final notifications = snapshot.data!.docs;
        if (query.parameters.containsKey('isRead')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _unreadCount = notifications.length);
          });
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notificationDoc = notifications[index];
            final notificationData =
                notificationDoc.data() as Map<String, dynamic>;
            final title = notificationData['title'] as String;
            final body = notificationData['body'] as String;
            final isRead = notificationData['isRead'] as bool;
            final type = notificationData['type'] as String;
            final rawTimestamp = notificationData['timestamp'];
            final DateTime timestamp = (rawTimestamp is Timestamp)
                ? rawTimestamp.toDate()
                : DateTime.now(); // fallback if missing/null

            return NotificationCard(
              title: title,
              body: body,
              isRead: isRead,
              type: type,
              timestamp: timestamp,
              onMarkAsRead: () =>
                  notificationDoc.reference.update({'isRead': true}),
              onDelete: () => _showDeleteConfirmationDialog(
                  context, notificationDoc.reference),
            );
          },
        );
      },
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final bool isRead;
  final String type;
  final DateTime timestamp;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;

  const NotificationCard({
    super.key,
    required this.title,
    required this.body,
    required this.isRead,
    required this.type,
    required this.timestamp,
    required this.onMarkAsRead,
    required this.onDelete,
  });

  // Method to get the color based on notification type
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'expired':
        return AppColors.orange;
      case 'presentAfterExpired':
        return AppColors.red;
      default:
        return AppColors.primaryBlue;
    }
  }

  // Method to get the icon based on notification type
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'expired':
        return Icons.event_busy;
      case 'presentAfterExpired':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isRead ? AppColors.backgroundLight : AppColors.cardBackground,
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
                Icon(
                  _getNotificationIcon(type),
                  color: _getNotificationColor(type),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat.yMMMd().format(timestamp),
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isRead)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline,
                        color: AppColors.green),
                    onPressed: onMarkAsRead,
                    tooltip: 'Mark as Read',
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.red),
                  onPressed: onDelete,
                  tooltip: 'Delete Notification',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
