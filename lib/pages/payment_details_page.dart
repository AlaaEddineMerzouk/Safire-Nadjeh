// 📁 lib/pages/payment_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class PaymentDetailsPage extends StatefulWidget {
  final Map<String, dynamic> paymentData;

  const PaymentDetailsPage({Key? key, required this.paymentData})
      : super(key: key);

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  bool _isLoading = true;
  String _teacherName = 'Loading...';
  final Map<String, String> _groupNames = {};
  final Map<String, String> _studentNames = {};
  final Map<String, Map<String, List<Map<String, String>>>>
      _studentsByGroupAndDate = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    log('DEBUG: Starting _fetchData()...');
    setState(() {
      _isLoading = true;
      _groupNames.clear();
      _studentNames.clear();
      _studentsByGroupAndDate.clear();
    });

    try {
      final teacherId = widget.paymentData['teacherId'] as String?;
      if (teacherId != null) {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('teachers')
            .doc(teacherId)
            .get();
        _teacherName =
            (teacherDoc.data()?['fullName'] as String?) ?? 'Unknown Teacher';
      }

      final earningsBreakdown =
          widget.paymentData['earningsBreakdown'] as List<dynamic>? ?? [];
      final studentsPaidFor =
          widget.paymentData['studentsPaidFor'] as List<dynamic>? ?? [];

      final uniqueGroupIds = earningsBreakdown
          .map<String>((e) => e['groupId'] as String)
          .toSet()
          .toList();

      final uniqueStudentIds = studentsPaidFor
          .map<String>((e) => e['studentId'] as String)
          .toSet()
          .toList();

      if (uniqueStudentIds.isEmpty && uniqueGroupIds.isEmpty) {
        log('DEBUG: No student or group data found. Ending fetch.');
        setState(() => _isLoading = false);
        return;
      }

      log('DEBUG: Unique student IDs: $uniqueStudentIds');
      log('DEBUG: Unique group IDs from earnings: $uniqueGroupIds');

      final studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where(FieldPath.documentId, whereIn: uniqueStudentIds)
          .get();
      for (var doc in studentSnapshot.docs) {
        _studentNames[doc.id] =
            (doc.data()['studentName'] as String?) ?? 'Unknown Student';
      }
      log('DEBUG: Fetched student names: $_studentNames');

      final groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where(FieldPath.documentId, whereIn: uniqueGroupIds)
          .get();
      for (var doc in groupSnapshot.docs) {
        _groupNames[doc.id] =
            (doc.data()['groupName'] as String?) ?? 'Unknown Group';
      }
      log('DEBUG: Fetched group names: $_groupNames');

      for (var studentData in studentsPaidFor) {
        final studentId = studentData['studentId'] as String;
        final groupId = studentData['groupId'] as String;
        final attendanceDate = (studentData['date'] as Timestamp).toDate();
        final formattedAttendanceDate =
            DateFormat('MMM d, yyyy').format(attendanceDate);

        final studentName = _studentNames[studentId] ?? 'Unknown Student';
        log('DEBUG: Processing student: $studentName, Group: $groupId, Date: $formattedAttendanceDate');

        if (!_studentsByGroupAndDate.containsKey(groupId)) {
          _studentsByGroupAndDate[groupId] = {};
        }

        if (!_studentsByGroupAndDate[groupId]!
            .containsKey(formattedAttendanceDate)) {
          _studentsByGroupAndDate[groupId]![formattedAttendanceDate] = [];
        }

        _studentsByGroupAndDate[groupId]![formattedAttendanceDate]!.add({
          'studentName': studentName,
        });
      }

      log('DEBUG: Final grouped data map: $_studentsByGroupAndDate');
    } catch (e) {
      log('FATAL ERROR: Error fetching group, student, and teacher data: $e');
      _teacherName = 'Error Loading Name';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sharePaymentDetails() {
    if (_isLoading || _isProcessing) {
      log('DEBUG: Share button pressed while loading or processing. Action ignored.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final paidAmount =
          (widget.paymentData['paidAmount'] as num?)?.toDouble() ?? 0.0;
      final formattedDate = DateFormat('MMMM d, yyyy').format(DateTime.now());

      final earningsBreakdown =
          widget.paymentData['earningsBreakdown'] as List<dynamic>? ?? [];

      String breakdownText = '';
      for (var breakdown in earningsBreakdown) {
        final groupId = breakdown['groupId'] as String;
        final groupName = (groupId == 'remaining_balance_payoff')
            ? 'Remaining Balance'
            : _groupNames[groupId] ?? 'Unknown Group';
        final earnings = (breakdown['earnings'] as num?)?.toDouble() ?? 0.0;
        breakdownText += '\n• $groupName: \$${earnings.toStringAsFixed(2)}';
      }

      final message = '''
💰 Payment Details for $_teacherName
---
Date: $formattedDate
Amount Paid: \$${paidAmount.toStringAsFixed(2)}
Calculated Earnings: \$${(widget.paymentData['calculatedEarnings'] as num?)?.toDouble() ?? 0.0}
Remaining Balance: \$${(widget.paymentData['remainingBalance'] as num?)?.toDouble() ?? 0.0}
---
Earnings Breakdown:$breakdownText
''';
      log('DEBUG: Sharing text message: $message');
      Share.share(message);
    } catch (e) {
      log('ERROR: Sharing text failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _generateAndSharePdf() async {
    log('DEBUG: Attempting to generate and share PDF...');
    if (_isLoading || _isProcessing) {
      log('DEBUG: PDF generation aborted. Data is still loading or a process is running.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      log('DEBUG: Loading font from assets...');
      final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
      final arabicFont = pw.Font.ttf(fontData);
      log('DEBUG: Font loaded successfully.');

      final paidAmount =
          (widget.paymentData['paidAmount'] as num?)?.toDouble() ?? 0.0;
      final totalCalculatedEarnings =
          (widget.paymentData['calculatedEarnings'] as num?)?.toDouble() ?? 0.0;
      final earningsBreakdown =
          widget.paymentData['earningsBreakdown'] as List<dynamic>? ?? [];
      final paymentDate =
          (widget.paymentData['paymentDate'] as Timestamp?)?.toDate() ??
              DateTime.now();
      final lastPaymentDate =
          (widget.paymentData['lastPaymentDate'] as Timestamp?)?.toDate();
      final formattedDate =
          DateFormat('MMMM d, yyyy h:mm a').format(paymentDate);
      final formattedLastPaymentDate = lastPaymentDate != null
          ? DateFormat('MMMM d, yyyy h:mm a').format(lastPaymentDate)
          : 'No previous payment';

      final remainingValue =
          (widget.paymentData['remainingBalance'] as num?)?.toDouble() ?? 0.0;

      log('DEBUG: Creating PDF document...');
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFont,
        ),
      );

      log('DEBUG: Adding MultiPage to PDF...');
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment
                      .start, // Changed to start for receipt alignment
                  children: [
                    pw.Center(
                      child: pw.Text('Payment Receipt',
                          style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              font: arabicFont)),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text('Teacher: $_teacherName',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            font: arabicFont)),
                    pw.Divider(height: 1, thickness: 0.5),
                    pw.SizedBox(height: 10),
                    _buildPdfReceiptRow('Payment Date:', formattedDate),
                    _buildPdfReceiptRow(
                        'Previous Payment:', formattedLastPaymentDate),
                    _buildPdfReceiptRow(
                        'Amount Paid:', '\$${paidAmount.toStringAsFixed(2)}'),
                    _buildPdfReceiptRow('Calculated Earnings:',
                        '\$${totalCalculatedEarnings.toStringAsFixed(2)}'),
                    if (remainingValue > 0)
                      _buildPdfReceiptRow('Remaining Balance:',
                          '\$${remainingValue.toStringAsFixed(2)}'),
                    pw.SizedBox(height: 20),
                    if (earningsBreakdown.isNotEmpty) ...[
                      pw.Text('Earnings Breakdown:',
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              font: arabicFont)),
                      pw.SizedBox(height: 5),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: earningsBreakdown.map((breakdown) {
                          final groupId = breakdown['groupId'] as String;
                          final groupName =
                              (groupId == 'remaining_balance_payoff')
                                  ? 'Remaining Balance'
                                  : _groupNames[groupId] ?? 'Unknown Group';
                          final students =
                              breakdown['presentStudents'] as int? ?? 0;
                          final earnings =
                              (breakdown['earnings'] as num?)?.toDouble() ??
                                  0.0;
                          final isRemainingBalance =
                              (groupId == 'remaining_balance_payoff');

                          return pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  isRemainingBalance
                                      ? groupName
                                      : '$groupName ($students students)',
                                  style: pw.TextStyle(
                                      fontSize: 12, font: arabicFont),
                                ),
                                pw.Text(
                                  '\$${earnings.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      font: arabicFont),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      pw.SizedBox(height: 20),
                    ],
                    if (_studentsByGroupAndDate.isNotEmpty) ...[
                      pw.Text('Students Paid For:',
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              font: arabicFont)),
                      pw.SizedBox(height: 5),
                      ..._studentsByGroupAndDate.entries.map((groupEntry) {
                        final groupName =
                            _groupNames[groupEntry.key] ?? 'Unknown Group';
                        final dates = groupEntry.value;

                        return pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start, // Changed to start
                          children: [
                            pw.Text(
                              'Group: $groupName',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                  font: arabicFont),
                            ),
                            pw.SizedBox(height: 3),
                            ...dates.entries.map((dateEntry) {
                              final date = dateEntry.key;
                              final studentsForDate = dateEntry.value;
                              return pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment
                                    .start, // Changed to start
                                children: [
                                  pw.Text('Date: $date',
                                      style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                          fontSize: 12,
                                          font: arabicFont)),
                                  pw.SizedBox(height: 3),
                                  ...studentsForDate.map((studentData) {
                                    return pw.Padding(
                                      padding:
                                          const pw.EdgeInsets.only(left: 10),
                                      child: pw.Text(
                                          '- ${studentData['studentName']!}',
                                          style: pw.TextStyle(
                                              fontSize: 10, font: arabicFont)),
                                    );
                                  }).toList(),
                                  pw.SizedBox(height: 5),
                                ],
                              );
                            }).toList(),
                            pw.SizedBox(height: 5),
                          ],
                        );
                      }).toList(),
                    ],
                    pw.SizedBox(height: 30),
                    pw.Center(
                      child: pw.Text('Thank you for your payment!',
                          style: pw.TextStyle(fontSize: 12, font: arabicFont)),
                    ),
                    pw.Center(
                      child: pw.Text(
                          'Generated by Safire El Nadjeh', // Changed this line
                          style: pw.TextStyle(
                              fontSize: 10,
                              font: arabicFont,
                              color: PdfColors.grey)),
                    ),
                    pw.Center(
                      child: pw.Text('Achaacha, Mostaganem, Algeria',
                          style: pw.TextStyle(
                              fontSize: 10,
                              font: arabicFont,
                              color: PdfColors.grey)),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final String filename =
          '${_teacherName}_payment_receipt_${DateFormat('yyyy-MM-dd').format(paymentDate)}.pdf';

      log('DEBUG: PDF creation successful. Attempting to save/share...');
      await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
      log('DEBUG: PDF shared successfully.');
    } on Exception catch (e) {
      log('FATAL ERROR: PDF generation and/or sharing failed: $e');
      debugPrintStack(); // Prints the full stack trace for detailed debugging.
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  pw.Widget _buildPdfReceiptRow(String title, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    log('DEBUG: Building PaymentDetailsPage for ${_teacherName}');
    final paidAmount =
        (widget.paymentData['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final totalCalculatedEarnings =
        (widget.paymentData['calculatedEarnings'] as num?)?.toDouble() ?? 0.0;
    final earningsBreakdown =
        widget.paymentData['earningsBreakdown'] as List<dynamic>? ?? [];
    final paymentDate =
        (widget.paymentData['paymentDate'] as Timestamp?)?.toDate() ??
            DateTime.now();
    final lastPaymentDate =
        (widget.paymentData['lastPaymentDate'] as Timestamp?)?.toDate();
    final formattedDate = DateFormat('MMMM d, yyyy h:mm a').format(paymentDate);
    final formattedLastPaymentDate = lastPaymentDate != null
        ? DateFormat('MMMM d, yyyy h:mm a').format(lastPaymentDate)
        : 'No previous payment';

    final remainingValue =
        (widget.paymentData['remainingBalance'] as num?)?.toDouble() ?? 0.0;

    if (_isLoading) {
      log('DEBUG: isLoading is true, showing CircularProgressIndicator');
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Loading...',
              style: const TextStyle(color: AppColors.textOnPrimary)),
          backgroundColor: AppColors.appBar,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
      );
    }

    log('DEBUG: isLoading is false, building main content.');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${_teacherName} Payment Details',
            style: const TextStyle(color: AppColors.textOnPrimary)),
        backgroundColor: AppColors.appBar,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(15),
                boxShadow: AppColors.cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Summary',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                    const SizedBox(height: 24),
                    _buildSummaryRow(
                      context,
                      'Date',
                      formattedDate,
                      Icons.calendar_today_rounded,
                      AppColors.primaryBlue,
                    ),
                    _buildSummaryRow(
                      context,
                      'Previous Payment Date',
                      formattedLastPaymentDate,
                      Icons.access_time_rounded,
                      AppColors.textSecondary,
                    ),
                    _buildSummaryRow(
                      context,
                      'Amount Paid',
                      '\$${paidAmount.toStringAsFixed(2)}',
                      Icons.attach_money_rounded,
                      AppColors.green,
                    ),
                    _buildSummaryRow(
                      context,
                      'Total Calculated Earnings',
                      '\$${totalCalculatedEarnings.toStringAsFixed(2)}',
                      Icons.calculate_rounded,
                      AppColors.primaryOrange,
                    ),
                    if (remainingValue > 0)
                      _buildSummaryRow(
                        context,
                        'Remaining Balance',
                        '\$${remainingValue.toStringAsFixed(2)}',
                        Icons.balance_rounded,
                        AppColors.red,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (earningsBreakdown.isNotEmpty) ...[
              Text('Earnings Breakdown by Group',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: earningsBreakdown.map((breakdown) {
                      final groupId = breakdown['groupId'] as String;
                      final groupName = (groupId == 'remaining_balance_payoff')
                          ? 'Remaining Balance'
                          : _groupNames[groupId] ?? 'Unknown Group';
                      final students =
                          breakdown['presentStudents'] as int? ?? 0;
                      final earnings = breakdown['earnings'] as num? ?? 0.0;
                      final isRemainingBalance =
                          (groupId == 'remaining_balance_payoff');

                      return _buildBreakdownRow(
                        context,
                        groupName,
                        students,
                        earnings.toDouble(),
                        isRemainingBalance,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (_studentsByGroupAndDate.isNotEmpty) ...[
              Text('Students Paid For',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _studentsByGroupAndDate.entries.map((groupEntry) {
                      final groupName =
                          _groupNames[groupEntry.key] ?? 'Unknown Group';
                      final dates = groupEntry.value;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group: $groupName',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ...dates.entries.map((dateEntry) {
                              final date = dateEntry.key;
                              final studentsForDate = dateEntry.value;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 16.0, top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date: $date',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...studentsForDate.map((studentData) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            left: 16.0, top: 4.0),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.person,
                                                color: AppColors.iconColor,
                                                size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '${studentData['studentName']!}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: (_isLoading || _isProcessing)
                      ? null
                      : _sharePaymentDetails,
                  icon: const Icon(Icons.share, color: AppColors.textOnPrimary),
                  label: const Text('Share',
                      style: TextStyle(color: AppColors.textOnPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: (_isLoading || _isProcessing)
                      ? null
                      : _generateAndSharePdf,
                  icon: const Icon(Icons.picture_as_pdf,
                      color: AppColors.textOnPrimary),
                  label: const Text('Save as PDF',
                      style: TextStyle(color: AppColors.textOnPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String groupName,
      int students, double earnings, bool isRemainingBalance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(isRemainingBalance ? Icons.wallet_giftcard : Icons.group,
              color: AppColors.purpleAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(groupName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                if (!isRemainingBalance)
                  Text('$students students present',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text('\$${earnings.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: AppColors.green)),
        ],
      ),
    );
  }
}
