import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TeacherFilterBar extends StatelessWidget {
  final String searchQuery;
  final String sortCriterion;
  final bool isDescending;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortCriterionChanged;
  final VoidCallback onSortDirectionChanged;

  const TeacherFilterBar({
    Key? key,
    required this.searchQuery,
    required this.sortCriterion,
    required this.isDescending,
    required this.onSearchChanged,
    required this.onSortCriterionChanged,
    required this.onSortDirectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textSecondary),
              hintText: 'Search by teacher name...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: AppColors.orange, width: 2),
              ),
            ),
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: sortCriterion,
                  dropdownColor: AppColors.cardBackground,
                  isExpanded: true,
                  // The list of items has been updated here
                  items: [
                    'Name',
                    'Remaining Balance',
                    'Last Payment Date',
                  ]
                      .map((criterion) => DropdownMenuItem(
                            value: criterion,
                            child: Text(criterion,
                                style: const TextStyle(
                                    color: AppColors.textPrimary)),
                          ))
                      .toList(),
                  onChanged: (val) => onSortCriterionChanged(val ?? 'Name'),
                  decoration: InputDecoration(
                    labelText: 'Sort By',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: IconButton(
                  onPressed: onSortDirectionChanged,
                  icon: Icon(
                    isDescending ? Icons.arrow_downward : Icons.arrow_upward,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
