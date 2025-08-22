import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

// Initialize local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// This is the dedicated service class that handles all notification logic.
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // The main function to be called when the admin logs in or opens the app
  Future<void> checkAndUpdateNotifications() async {
    // Check if the daily update has already been performed
    final lastUpdateDoc = await _firestore
        .collection('app_settings')
        .doc('daily_notification_check')
        .get();

    if (lastUpdateDoc.exists) {
      final lastUpdateTime =
          (lastUpdateDoc.data()?['timestamp'] as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(lastUpdateTime).inHours;

      if (difference < 24) {
        print("Daily notification check already performed today.");
        return; // Exit if check was done less than 24 hours ago
      }
    }

    print("Running daily notification check...");

    // ⭐️ FIX: Delete all existing notifications before running the check
    await deleteAllNotifications();
    print("All old notifications deleted.");

    // Now, find and create the new notifications
    await _findAndCreateStudentNotifications();

    // Update the timestamp to prevent multiple checks in one day
    await _firestore
        .collection('app_settings')
        .doc('daily_notification_check')
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
    print("Daily notification check complete. Timestamp updated.");
  }

  // Queries for expired subscriptions and creates notifications
  Future<void> _findAndCreateStudentNotifications() async {
    // Use an OR query to get documents where either field is true
    final subscriptions = await _firestore
        .collection('subscriptions')
        .where('hasExpired', isEqualTo: true)
        .get();

    int newExpiredCount = 0;
    int newPresentAfterExpiredCount = 0;

    for (var doc in subscriptions.docs) {
      final subscriptionData = doc.data();
      final hasExpired = subscriptionData['hasExpired'] ?? false;
      final hasPresentAfterExpired =
          subscriptionData['hasPresentAfterExpired'] ?? false;
      final studentId = subscriptionData['studentId'] as String;
      final studentName = subscriptionData['studentName'] as String;

      // Condition 1: Student had a presence after expiration (Red)
      // This is the priority check. If this is true, we stop here.
      if (hasPresentAfterExpired) {
        await _createNotification(
          title: 'Present After Expiration',
          body:
              'Student "$studentName" was present in a session after their subscription expired.',
          type: 'presentAfterExpired', // red style
          studentId: studentId,
        );
        newPresentAfterExpiredCount++;
      } else if (hasExpired) {
        // Condition 2: Subscription is expired (Orange)
        // This is only checked if Condition 1 was false.
        await _createNotification(
          title: 'Subscription Expired',
          body: 'The subscription for student "$studentName" has expired.',
          type: 'expired', // orange style
          studentId: studentId,
        );
        newExpiredCount++;
      }
    }

    // Show a local notification summarizing the new alerts
    if (newExpiredCount > 0 || newPresentAfterExpiredCount > 0) {
      String summaryMessage = 'You have new notifications: ';
      if (newExpiredCount > 0) {
        summaryMessage += '$newExpiredCount expired subscriptions. ';
      }
      if (newPresentAfterExpiredCount > 0) {
        summaryMessage +=
            '$newPresentAfterExpiredCount students were present after expiration.';
      }
      _showLocalNotification(summaryMessage);
    }
  }

  // Creates a new document in the 'notifications' collection
  Future<void> _createNotification({
    required String title,
    required String body,
    required String type,
    required String studentId,
  }) async {
    await _firestore.collection('notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'studentId': studentId,
      'isRead': false, // New notifications are unread by default
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Uses Flutter Local Notifications to show a notification to the admin
  Future<void> _showLocalNotification(String message) async {
    // The name of the icon must match a drawable resource in the Android project.
    // By default, the app icon is named 'ic_launcher'.
    const androidDetails = AndroidNotificationDetails(
      'daily_notifications_channel',
      'Daily Notifications',
      channelDescription: 'Notifications for daily admin checks',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_launcher', // Corrected icon name
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Daily Notification Update',
      message,
      platformDetails,
    );
  }

  // Deletes all notifications
  Future<void> deleteAllNotifications() async {
    final notifications = await _firestore.collection('notifications').get();
    for (var doc in notifications.docs) {
      await doc.reference.delete();
    }
  }

  // Marks all unread notifications as read
  Future<void> markAllAsRead() async {
    final unreadNotifications = await _firestore
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    for (var doc in unreadNotifications.docs) {
      await doc.reference.update({'isRead': true});
    }
  }
}
