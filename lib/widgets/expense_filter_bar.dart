import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

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
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Search Field
          TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textSecondary),
              hintText: 'Search by expense name...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.backgroundLight,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide:
                    const BorderSide(color: AppColors.inputBorder, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: AppColors.orange, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter + Sort Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: filterStatus,
                  dropdownColor: AppColors.cardBackground,
                  isExpanded: true,
                  items: const ['All', 'Paid', 'Unpaid']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(
                              status,
                              style:
                                  const TextStyle(color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: onFilterChanged,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: sortCriterion,
                        dropdownColor: AppColors.cardBackground,
                        isExpanded: true,
                        items: const ['Date', 'Amount']
                            .map((criterion) => DropdownMenuItem(
                                  value: criterion,
                                  child: Text(
                                    criterion,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: onSortCriterionChanged,
                        decoration: InputDecoration(
                          labelText: 'Sort By',
                          labelStyle:
                              const TextStyle(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.backgroundLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: IconButton(
                        onPressed: onSortDirectionChanged,
                        icon: Icon(
                          isDescending
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
