// 📁 lib/widgets/date_picker_field.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class DatePickerField extends StatefulWidget {
  final String label;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const DatePickerField({
    Key? key,
    required this.label,
    required this.selectedDate,
    required this.onDateChanged,
  }) : super(key: key);

  @override
  _DatePickerFieldState createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: DateFormat('dd MMM yyyy').format(widget.selectedDate),
    );
  }

  @override
  void didUpdateWidget(DatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _controller.text = DateFormat('dd MMM yyyy').format(widget.selectedDate);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.orange, // Header background
              onPrimary: Colors.white, // Header text
              surface: AppColors.cardBackground, // Calendar background
              onSurface: AppColors.textPrimary, // Calendar text
            ),
            dialogBackgroundColor: AppColors.backgroundLight,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != widget.selectedDate) {
      widget.onDateChanged(picked);
      _controller.text = DateFormat('dd MMM yyyy').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      onTap: () => _selectDate(context),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'Select a date',
        prefixIcon: const Icon(Icons.calendar_today),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            widget.onDateChanged(DateTime.now());
            _controller.text = DateFormat('dd MMM yyyy').format(DateTime.now());
          },
        ),
      ),
    );
  }
}
