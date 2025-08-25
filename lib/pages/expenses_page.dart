import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';

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

// Function to show the permanent delete confirmation dialog
  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text('Confirm Deletion',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
              'Are you sure you want to permanently delete this expense?',
              style: TextStyle(color: AppColors.red)),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(false), // Return false on cancel
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(true), // Return true on delete
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

// Function to show the archive confirmation dialog
  void _showArchiveConfirmation(BuildContext scaffoldContext, String docId) {
    showDialog(
      context: scaffoldContext,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text('Confirm Archiving',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('Are you sure you want to archive this expense?',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                await FirebaseFirestore.instance
                    .collection('expenses')
                    .doc(docId)
                    .update({'isArchived': true});

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(
                      content: Text('Expense archived successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );
  }

// Function to show the restore confirmation dialog
  void _showRestoreConfirmation(BuildContext scaffoldContext, String docId) {
    showDialog(
      context: scaffoldContext,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: const Text('Confirm Restore',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
              'Are you sure you want to restore this expense from archive?',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                await FirebaseFirestore.instance
                    .collection('expenses')
                    .doc(docId)
                    .update({'isArchived': false});

                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(
                      content: Text('Expense restored successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

// Function to show the status toggle confirmation dialog
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            Container(
              color: AppColors.backgroundLight,
              child: const TabBar(
                indicatorColor: AppColors.orange,
                labelColor: AppColors.orange,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(text: 'Unarchived'),
                  Tab(text: 'Archived'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
// First tab: Unarchived expenses with filters and sorting
                  _buildExpensesTab(isArchived: false),
// Second tab: Archived expenses as a simple list
                  _buildExpensesTab(isArchived: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesTab({required bool isArchived}) {
    return Column(
      children: [
        if (!isArchived)
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
            stream: FirebaseFirestore.instance
                .collection('expenses')
                .where('isArchived', isEqualTo: isArchived)
                .snapshots(),
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
                return Center(
                  child: Text(
                      'No ${isArchived ? 'archived' : 'unarchived'} expenses found.',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 16)),
                );
              }

              List<DocumentSnapshot> filteredDocs = snapshot.data!.docs;

// Apply filtering and sorting only for the unarchived tab
              if (!isArchived) {
// 1. Filter by status
                if (_filterStatus != 'All') {
                  filteredDocs = filteredDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status'] == _filterStatus;
                  }).toList();
                }

// 2. Filter by search query
                filteredDocs = filteredDocs.where((doc) {
                  final expenseName =
                      (doc.data() as Map<String, dynamic>)['name']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                  return expenseName.contains(_searchQuery.toLowerCase());
                }).toList();

// 3. Sort the filtered list
                filteredDocs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;

                  if (_sortCriterion == 'Date') {
                    final dateA = (dataA['date'] as Timestamp).toDate();
                    final dateB = (dataB['date'] as Timestamp).toDate();
                    return _isDescending
                        ? dateB.compareTo(dateA)
                        : dateA.compareTo(dateB);
                  } else if (_sortCriterion == 'Amount') {
                    final amountA = (dataA['amount'] as num).toDouble();
                    final amountB = (dataB['amount'] as num).toDouble();
                    return _isDescending
                        ? amountB.compareTo(amountA)
                        : amountA.compareTo(amountB);
                  }
                  return 0;
                });
              }

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text('No expenses match your search or filter.',
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

// Use a Dismissible widget for swipe-to-delete
                  return Dismissible(
                    key: Key(doc.id), // Unique key is required
                    direction: DismissDirection.horizontal,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: AppColors.red, // Always red for deletion
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: AppColors.red, // Always red for deletion
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
// Use confirmDismiss to control the dismissal process
                    confirmDismiss: (direction) async {
                      final confirmed = await _showDeleteConfirmation(context);
                      if (confirmed == true) {
// User confirmed deletion, now perform the delete action
                        await FirebaseFirestore.instance
                            .collection('expenses')
                            .doc(doc.id)
                            .delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Expense deleted successfully!')),
                        );
                        return true; // Return true to dismiss the card
                      }
                      return false; // Return false to prevent dismissal
                    },
                    child: ExpenseCard(
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
                      onToggleStatus: () => _showToggleStatusConfirmation(
                          context, doc.id, data['status'] ?? 'Unpaid'),
// Only show archive/restore button if the item is archived
                      onArchive: isArchived
                          ? () => _showRestoreConfirmation(context, doc.id)
                          : () => _showArchiveConfirmation(context, doc.id),
                      isArchived: isArchived,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- Placeholder for ExpenseCard, AppColors, etc. for completeness ---
class ExpenseCard extends StatelessWidget {
  final String name;
  final double amount;
  final String status;
  final DateTime date;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onArchive;
  final bool isArchived;

  const ExpenseCard({
    Key? key,
    required this.name,
    required this.amount,
    required this.status,
    required this.date,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onArchive,
    required this.isArchived,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status == 'Paid' ? AppColors.green : AppColors.red,
          child: Icon(status == 'Paid' ? Icons.check : Icons.close,
              color: Colors.white),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${date.day}/${date.month}/${date.year} - $status'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
            if (isArchived) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.unarchive, color: AppColors.green),
                onPressed: onArchive,
                tooltip: 'Restore from Archive',
              ),
            ] else ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.archive, color: AppColors.orange),
                onPressed: onArchive,
                tooltip: 'Archive',
              ),
            ],
          ],
        ),
        onTap: onEdit,
        onLongPress: onToggleStatus,
      ),
    );
  }
}

class ExpenseFilterBar extends StatelessWidget {
  final String searchQuery;
  final String filterStatus;
  final String sortCriterion;
  final bool isDescending;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onFilterChanged;
  final ValueChanged<String?> onSortCriterionChanged;
  final VoidCallback onSortDirectionChanged;

  const ExpenseFilterBar({
    Key? key,
    required this.searchQuery,
    required this.filterStatus,
    required this.sortCriterion,
    required this.isDescending,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortCriterionChanged,
    required this.onSortDirectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the current orientation
    final orientation = MediaQuery.of(context).orientation;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: AppColors.backgroundLight,
      // Fix: Wrap the Column in a SingleChildScrollView to prevent vertical overflow
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Conditionally render the search box
            if (orientation == Orientation.portrait) ...[
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.orange, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                onChanged: onSearchChanged,
              ),
              const SizedBox(height: 12),
            ],
            // Use an expanded widget with the row to make the dropdowns fit correctly
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    items: ['All', 'Paid', 'Unpaid']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: onFilterChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: sortCriterion,
                    decoration: const InputDecoration(
                      labelText: 'Sort By',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    items: ['Date', 'Amount']
                        .map((criterion) => DropdownMenuItem(
                              value: criterion,
                              child: Text(criterion),
                            ))
                        .toList(),
                    onChanged: onSortCriterionChanged,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                      isDescending ? Icons.arrow_downward : Icons.arrow_upward),
                  onPressed: onSortDirectionChanged,
                  tooltip: 'Toggle sort direction',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder for AppColors
class AppColors {
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryOrange = Color(0xFFFF8A00);
  static const Color purple = Color(0xFF7C4DFF);
  static const Color red = Colors.redAccent;
  static const Color green = Color(0xFF4CAF50);
  static const Color background = Color(0xFFF0F4F8);
  static const Color backgroundLight = Colors.white;
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color orange = Colors.deepOrange;
  static const Color primary = Colors.blue;
}
