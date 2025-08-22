import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../widgets/expense_card.dart';
import '../widgets/expense_filter_bar.dart';
import 'add_expense_page.dart';
import 'edit_expense_page.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({Key? key}) : super(key: key);

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _sortCriterion = 'Date';
  bool _isDescending = true;

  Stream<QuerySnapshot> _getExpensesStream() {
    Query query = FirebaseFirestore.instance.collection('expenses');

    if (_sortCriterion == 'Date') {
      query = query.orderBy('date', descending: _isDescending);
    } else if (_sortCriterion == 'Amount') {
      query = query.orderBy('amount', descending: _isDescending);
    }

    if (_filterStatus != 'All') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return query.snapshots();
  }

  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('Are you sure you want to delete this expense?',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('expenses')
                    .doc(docId)
                    .delete();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Expense deleted successfully!')),
                );
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

  void _showToggleStatusConfirmation(
      BuildContext context, String docId, String currentStatus) {
    final newStatus = currentStatus == 'Paid' ? 'Unpaid' : 'Paid';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text('Confirm Status Change',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
              'Are you sure you want to mark this expense as $newStatus?',
              style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('expenses')
                    .doc(docId)
                    .update({
                  'status': newStatus,
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Expense marked as $newStatus')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Mark as $newStatus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpensePage()),
          );
        },
      ),
      body: Column(
        children: [
          ExpenseFilterBar(
            searchQuery: _searchQuery,
            filterStatus: _filterStatus,
            sortCriterion: _sortCriterion,
            isDescending: _isDescending,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            onFilterChanged: (value) => setState(() => _filterStatus = value!),
            onSortCriterionChanged: (value) =>
                setState(() => _sortCriterion = value!),
            onSortDirectionChanged: () =>
                setState(() => _isDescending = !_isDescending),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getExpensesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Something went wrong: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No expenses found.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final expenseName =
                      (doc.data() as Map<String, dynamic>)['name']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                  return expenseName.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('No expenses match your search.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return ExpenseCard(
                      name: data['name'] ?? '',
                      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
                      status: data['status'] ?? 'Unpaid',
                      date: (data['date'] as Timestamp?)?.toDate() ??
                          DateTime.now(),
                      onEdit: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditExpensePage(
                                expenseData: data, docId: doc.id),
                          ),
                        );
                      },
                      onDelete: () => _showDeleteConfirmation(context, doc.id),
                      onToggleStatus: () => _showToggleStatusConfirmation(
                          context, doc.id, data['status'] ?? 'Unpaid'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
