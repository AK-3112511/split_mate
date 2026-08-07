import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/groups/domain/group_expense_model.dart';

class ExportHelper {
  /// Format category IDs into user-friendly category names
  static String formatCategoryName(String rawCategory, [Map<String, String>? categoryNamesMap]) {
    if (rawCategory.trim().isEmpty) return 'General';
    final clean = rawCategory.trim();

    if (categoryNamesMap != null && categoryNamesMap.containsKey(clean)) {
      final found = categoryNamesMap[clean]!;
      if (found.isNotEmpty) return found;
    }

    final presetMap = {
      'food_dining': 'Food & Dining',
      'food': 'Food & Dining',
      'dining': 'Food & Dining',
      'groceries': 'Groceries',
      'grocery': 'Groceries',
      'shopping': 'Shopping',
      'transportation': 'Transportation',
      'transport': 'Transportation',
      'travel': 'Transportation',
      'utilities': 'Utilities',
      'utility': 'Utilities',
      'bills': 'Utilities',
      'entertainment': 'Entertainment',
      'movies': 'Entertainment',
      'rent': 'Rent & Bills',
      'general': 'General',
      'other': 'General',
    };

    if (presetMap.containsKey(clean.toLowerCase())) {
      return presetMap[clean.toLowerCase()]!;
    }

    // Fallback if category ID is a raw UUID string
    if (RegExp(r'^[0-9a-fA-F\s\-]{20,}$').hasMatch(clean)) {
      return 'General';
    }

    return rawCategory
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  /// Generate human-readable portion breakdown text for splits using Rs.
  static String _buildPortionBreakdownText(
    Map<String, double> splits,
    Map<String, String> memberNames,
  ) {
    final List<String> parts = [];
    splits.forEach((uid, amount) {
      if (amount > 0.001) {
        final name = memberNames[uid] ?? 'Member';
        parts.add('$name: Rs. ${amount.toStringAsFixed(2)}');
      }
    });
    return parts.isEmpty ? 'None' : parts.join(' | ');
  }

  /// Generates PDF file on disk and returns its file path
  static Future<String> generateGroupExpensesPDFFile({
    required String groupName,
    required List<GroupExpenseModel> expenses,
    required Map<String, String> memberNames,
    Map<String, String>? categoryNames,
  }) async {
    final pdf = pw.Document();

    // 1. Compute Analytics & Category Summary
    final sortedMemberUids = memberNames.keys.toList()..sort();
    final Map<String, double> netBalances = {
      for (var uid in sortedMemberUids) uid: 0.0,
    };
    final Map<String, double> totalPaidByMember = {
      for (var uid in sortedMemberUids) uid: 0.0,
    };
    final Map<String, double> totalOwedByMember = {
      for (var uid in sortedMemberUids) uid: 0.0,
    };

    double totalGroupSpend = 0.0;
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};

    for (final e in expenses) {
      if (!e.isSettlement) {
        totalGroupSpend += e.amount;

        // Category breakdown
        final catName = formatCategoryName(e.category, categoryNames);
        categoryTotals[catName] = (categoryTotals[catName] ?? 0.0) + e.amount;
        categoryCounts[catName] = (categoryCounts[catName] ?? 0) + 1;
      }

      // Payer and splits for net balances
      totalPaidByMember[e.payerUid] = (totalPaidByMember[e.payerUid] ?? 0.0) + e.amount;
      netBalances[e.payerUid] = (netBalances[e.payerUid] ?? 0.0) + e.amount;

      e.splits.forEach((uid, owed) {
        totalOwedByMember[uid] = (totalOwedByMember[uid] ?? 0.0) + owed;
        netBalances[uid] = (netBalances[uid] ?? 0.0) - owed;
      });
    }

    // Color definitions
    final darkHeaderBg = PdfColor.fromHex('#1E242B');
    final goldAccent = PdfColor.fromHex('#D4AF37');
    final lightCardBg = PdfColor.fromHex('#F4F6F8');

    final generatedTimeStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // 2. Build PDF MultiPage document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(
              color: darkHeaderBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SPLITMATE',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    pw.Text(
                      'EXPENSE & SETTLEMENT AUDIT REPORT',
                      style: pw.TextStyle(
                        color: goldAccent,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      groupName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Generated: $generatedTimeStr',
                      style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SplitMate Financial Audit • Group: $groupName',
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(color: PdfColors.grey800, fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // KPI Summary Grid Cards
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightCardBg,
                      border: pw.Border.all(color: goldAccent, width: 1.0),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL GROUP SPEND', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('Rs. ${totalGroupSpend.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkHeaderBg)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightCardBg,
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL EXPENSES', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('${expenses.length} Entries', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkHeaderBg)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightCardBg,
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ACTIVE MEMBERS', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('${memberNames.length} Members', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkHeaderBg)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // SECTION 1: Category Breakdown Table
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              color: darkHeaderBg,
              child: pw.Text(
                'SPENDING BREAKDOWN BY CATEGORY',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: goldAccent, letterSpacing: 1.0),
              ),
            ),
            pw.SizedBox(height: 6),

            if (categoryTotals.isEmpty)
              pw.Text('No expenses recorded.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Category Name', 'Total Spent (INR)', 'Share %', 'Items Count'],
                data: categoryTotals.entries.map((entry) {
                  final catName = entry.key;
                  final amount = entry.value;
                  final pct = totalGroupSpend > 0 ? (amount / totalGroupSpend * 100).toStringAsFixed(1) : '0.0';
                  final count = categoryCounts[catName] ?? 0;
                  return [catName, 'Rs. ${amount.toStringAsFixed(2)}', '$pct%', '$count items'];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
                cellStyle: const pw.TextStyle(fontSize: 8),
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                  bottom: pw.BorderSide(width: 0.8, color: PdfColors.grey400),
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),

            pw.SizedBox(height: 20),

            // SECTION 2: Itemized Expense Ledger Table
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              color: darkHeaderBg,
              child: pw.Text(
                'ITEMIZED EXPENSE LEDGER',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: goldAccent, letterSpacing: 1.0),
              ),
            ),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Date', 'Description', 'Category', 'Paid By', 'Split Type', 'Amount', 'Portion Breakdown'],
              data: expenses.asMap().entries.map((entry) {
                final e = entry.value;
                final dateStr = DateFormat('yyyy-MM-dd').format(e.createdAt);
                final categoryName = formatCategoryName(e.category, categoryNames);
                final payerName = memberNames[e.payerUid] ?? 'Unknown';
                final splitType = e.splitType.toUpperCase();
                final portionText = _buildPortionBreakdownText(e.splits, memberNames);

                return [
                  dateStr,
                  e.description,
                  categoryName,
                  payerName,
                  splitType,
                  'Rs. ${e.amount.toStringAsFixed(2)}',
                  portionText,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              cellStyle: const pw.TextStyle(fontSize: 8),
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                bottom: pw.BorderSide(width: 0.8, color: PdfColors.grey400),
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                5: pw.Alignment.centerRight,
              },
            ),

            pw.SizedBox(height: 20),

            // SECTION 3: Current Net Positions Table
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              color: darkHeaderBg,
              child: pw.Text(
                'MEMBER NET BALANCES & SETTLEMENT STATUS',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: goldAccent, letterSpacing: 1.0),
              ),
            ),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Member Name', 'Total Paid (INR)', 'Total Owed (INR)', 'Net Position Status'],
              data: sortedMemberUids.map((uid) {
                final name = memberNames[uid] ?? 'Unknown';
                final paid = totalPaidByMember[uid] ?? 0.0;
                final owed = totalOwedByMember[uid] ?? 0.0;
                final net = netBalances[uid] ?? 0.0;

                String status = 'Settled Up';
                if (net > 0.01) {
                  status = 'OWED Rs. ${net.toStringAsFixed(2)}';
                } else if (net < -0.01) {
                  status = 'OWES Rs. ${net.abs().toStringAsFixed(2)}';
                }

                return [
                  name,
                  'Rs. ${paid.toStringAsFixed(2)}',
                  'Rs. ${owed.toStringAsFixed(2)}',
                  status,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              cellStyle: const pw.TextStyle(fontSize: 8),
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                bottom: pw.BorderSide(width: 0.8, color: PdfColors.grey400),
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerLeft,
              },
            ),
          ];
        },
      ),
    );

    // Save to file
    final tempDir = await getTemporaryDirectory();
    final sanitizedGroupName = groupName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final filePath = '${tempDir.path}/${sanitizedGroupName}_expenses.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  /// Export Group Expenses to Executive PDF with visual design, category breakdowns, and settlement positions
  static Future<void> exportGroupExpensesToPDF({
    required String groupName,
    required List<GroupExpenseModel> expenses,
    required Map<String, String> memberNames,
    Map<String, String>? categoryNames,
  }) async {
    final filePath = await generateGroupExpensesPDFFile(
      groupName: groupName,
      expenses: expenses,
      memberNames: memberNames,
      categoryNames: categoryNames,
    );

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: '$groupName Shared Ledger PDF Export',
      text: 'Here is the exported PDF ledger report for SplitMate group "$groupName".',
    );
  }

  static Future<void> shareGroupInviteCode({
    required String groupName,
    required String inviteCode,
  }) async {
    final cleanCode = inviteCode.trim().toUpperCase();
    final message = '''Join my group "$groupName" on SplitMate!

Group Code: *$cleanCode*

Open SplitMate -> Groups -> Join Group and enter the code *$cleanCode*.''';

    await Share.share(message, subject: 'Join $groupName on SplitMate');
  }

  static Future<void> shareFriendAppCode({
    required String appCode,
    required String displayName,
  }) async {
    final cleanCode = appCode.trim().toUpperCase();
    final message = '''Connect with me on SplitMate!

My Friend Code: *$cleanCode*

Open SplitMate -> Friends -> Connect and enter my code *$cleanCode*.''';

    await Share.share(message, subject: 'Connect with $displayName on SplitMate');
  }
}
