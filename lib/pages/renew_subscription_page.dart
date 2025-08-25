// 📁 lib/pages/renew_subscription_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class RenewSubscriptionPage extends StatefulWidget {
  final Map<String, dynamic> subscriptionData;
  final String docId;

  const RenewSubscriptionPage({
    Key? key,
    required this.subscriptionData,
    required this.docId,
  }) : super(key: key);

  @override
  State<RenewSubscriptionPage> createState() => _RenewSubscriptionPageState();
}

class _RenewSubscriptionPageState extends State<RenewSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  // Removed _sessionsController as per user request

  DateTime _newPaymentDate = DateTime.now();
  DateTime _newEndDate = DateTime.now().add(const Duration(days: 30));

  bool _isLoading = false;
  String? _groupName;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data
    _priceController.text = widget.subscriptionData['price']?.toString() ?? '';
    // Removed _sessionsController initialization

    // Asynchronously fetch the group name using the groupId
    _fetchGroupName();
  }

  @override
  void dispose() {
    _priceController.dispose();
    // Removed _sessionsController disposal
    super.dispose();
  }

  /// Fetches the group name from Firestore using the groupId.
  Future<void> _fetchGroupName() async {
    final groupId = widget.subscriptionData['groupId'];
    if (groupId != null) {
      try {
        final groupDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .get();
        if (groupDoc.exists) {
          setState(() {
            _groupName = groupDoc.data()?['groupName'] ?? 'Not specified';
          });
        } else {
          // Handle case where group document does not exist
          setState(() {
            _groupName = 'Not specified';
          });
        }
      } catch (e) {
        // Handle potential errors during fetching
        setState(() {
          _groupName = 'Error fetching group name';
        });
        print('Error fetching group name: $e');
      }
    } else {
      // Handle case where no groupId is present in the subscription
      setState(() {
        _groupName = 'Not specified';
      });
    }
  }

  /// Shows the date picker dialog and updates the selected date.
  Future<void> _showDatePickerDialog(BuildContext context,
      DateTime? initialDate, ValueChanged<DateTime?> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.textOnPrimary,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
          dialogBackgroundColor: AppColors.cardBackground,
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  /// Builds a tappable container for selecting a date.
  Widget _buildDateField(
      String label, DateTime? date, ValueChanged<DateTime?> onPicked) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return InkWell(
      onTap: () => _showDatePickerDialog(context, date, onPicked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null ? dateFormat.format(date) : label,
              style: TextStyle(
                color: date != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            Icon(Icons.calendar_today,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  /// Handles the subscription renewal logic.
  Future<void> _renewSubscription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(widget.docId);

      final oldSubscriptionData = widget.subscriptionData;

      // 1. Save a copy of the old subscription to a 'renewals' subcollection
      await docRef.collection('renewals').add({
        'price': oldSubscriptionData['price'],
        'paymentDate': oldSubscriptionData['paymentDate'],
        'endDate': oldSubscriptionData['endDate'],
        'numberOfSessions': oldSubscriptionData['numberOfSessions'],
        'firstLessonDate': oldSubscriptionData['firstLessonDate'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update the parent subscription document with the new renewal data
      await docRef.update({
        'price': double.tryParse(_priceController.text),
        'paymentDate': Timestamp.fromDate(_newPaymentDate),
        'endDate': Timestamp.fromDate(_newEndDate),
        // Removed 'numberOfSessions' from the update
        'status': 'Active',
      });

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Subscription renewed successfully!'),
            backgroundColor: AppColors.green),
      );

      Navigator.of(context).pop();
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to renew subscription: $e'),
            backgroundColor: AppColors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecorationTheme = InputDecorationTheme(
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    final subjects =
        List<String>.from(widget.subscriptionData['subjects'] ?? []);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        title: const Text(
          'Renew Subscription',
          style: TextStyle(color: AppColors.textOnPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
      ),
      body: Theme(
        data: Theme.of(context)
            .copyWith(inputDecorationTheme: inputDecorationTheme),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Student: ${widget.subscriptionData['studentName'] ?? 'Not specified'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Group: ${_groupName ?? 'Loading...'}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // Displaying the subjects here
                if (subjects.isNotEmpty)
                  Text(
                    'Subjects: ${subjects.join(', ')}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 24),
                // New Price field
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'New Price',
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Removed the Number of Sessions field
                // New Payment Date field
                _buildDateField(
                  "New Payment Date",
                  _newPaymentDate,
                  (date) {
                    setState(() {
                      _newPaymentDate = date!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // New End Date field
                _buildDateField(
                  "New End Date",
                  _newEndDate,
                  (date) {
                    setState(() {
                      _newEndDate = date!;
                    });
                  },
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _renewSubscription,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Renew Subscription',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
