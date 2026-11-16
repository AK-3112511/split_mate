import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/domain/settlement.dart';
import '../../core/utils/money.dart';
import '../categories/domain/category_model.dart';
import '../categories/domain/category_resolver.dart';
import '../groups/domain/group_expense_model.dart';
import '../personal_expenses/domain/expense_model.dart';

/// CSV / PDF exports. PDFs use "Rs." because the bundled PDF fonts have no ₹ glyph.
class ExportService {
  ExportService._();

  static final DateFormat _day = DateFormat('d MMM yyyy');
  static final NumberFormat _num = NumberFormat('#,##,##0.00', 'en_IN');
  static String rs(num v) => 'Rs. ${_num.format(Money.round2(v))}';

  static PdfColor get _violet => PdfColor.fromHex('#6D4AFF');
  static PdfColor get _muted => PdfColor.fromHex('#5B6085');
  static PdfColor get _soft => PdfColor.fromHex('#EEF0F8');

  static Future<File> _write(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_\-.]'), '_');
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> _share(File file, String subject) async {
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }

  static String _csvCell(String v) {
    final needsQuotes = v.contains(',') || v.contains('"') || v.contains('\n');
    final escaped = v.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  // ── Personal ──────────────────────────────────────────────────────────────

  static String personalCsv(List<ExpenseModel> expenses, List<CategoryModel> categories) {
    final buf = StringBuffer('Date,Description,Category,Amount (INR),Source,Notes\n');
    for (final e in expenses) {
      final cat = CategoryResolver.resolve(id: e.categoryId, name: e.categoryName, categories: categories);
      buf.writeln([
        _day.format(e.date),
        _csvCell(e.description),
        _csvCell(cat.name),
        Money.round2(e.amount).toStringAsFixed(2),
        _csvCell(e.isMirror ? 'Group: ${e.sourceGroupName ?? ''}' : 'Personal'),
        _csvCell(e.notes ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  static Future<void> sharePersonalCsv({
    required List<ExpenseModel> expenses,
    required List<CategoryModel> categories,
    required String label,
  }) async {
    final file = await _write('SplitMate_$label.csv', personalCsv(expenses, categories).codeUnits);
    await _share(file, 'SplitMate expenses — $label');
  }

  static Future<void> sharePersonalPdf({
    required List<ExpenseModel> expenses,
    required List<CategoryModel> categories,
    required String label,
    required String ownerName,
  }) async {
    final doc = pw.Document();
    final total = expenses.fold<double>(0, (a, e) => a + e.amount);
    final byCat = CategoryResolver.totals<ExpenseModel>(
      items: expenses,
      categoryOf: (e) => CategoryResolver.resolve(id: e.categoryId, name: e.categoryName, categories: categories),
      amountOf: (e) => e.amount,
    );
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _header('Spending report', '$ownerName · $label'),
      footer: _footer,
      build: (_) => [
        _statRow([('Total spent', rs(total)), ('Entries', '${expenses.length}')]),
        pw.SizedBox(height: 18),
        _title('By category'),
        _table(
          ['Category', 'Amount', 'Share'],
          [
            for (final e in byCat)
              [e.key.name, rs(e.value), total <= 0 ? '0%' : '${(e.value / total * 100).toStringAsFixed(1)}%'],
          ],
          align: const [pw.Alignment.centerLeft, pw.Alignment.centerRight, pw.Alignment.centerRight],
        ),
        pw.SizedBox(height: 18),
        _title('All expenses'),
        _table(
          ['Date', 'Description', 'Category', 'Amount'],
          [
            for (final e in expenses)
              [
                _day.format(e.date),
                e.description,
                CategoryResolver.resolve(id: e.categoryId, name: e.categoryName, categories: categories).name,
                rs(e.amount),
              ],
          ],
          align: const [
            pw.Alignment.centerLeft,
            pw.Alignment.centerLeft,
            pw.Alignment.centerLeft,
            pw.Alignment.centerRight,
          ],
        ),
      ],
    ));
    final file = await _write('SplitMate_$label.pdf', await doc.save());
    await _share(file, 'SplitMate report — $label');
  }

  // ── Group ─────────────────────────────────────────────────────────────────

  static Future<void> shareGroupPdf({
    required String groupName,
    required List<GroupExpenseModel> expenses,
    required List<String> members,
    required String Function(String uid) nameOf,
  }) async {
    final doc = pw.Document();
    final spending = expenses.where((e) => !e.isPayment).toList();
    final payments = expenses.where((e) => e.isPayment).toList();
    final total = spending.fold<double>(0, (a, e) => a + e.amount);
    final net = Settlement.netBalances(expenses, members: members);
    final debts = Settlement.pairwiseDebts(expenses);
    final paid = <String, double>{};
    final share = <String, double>{};
    for (final e in spending) {
      paid[e.payerUid] = (paid[e.payerUid] ?? 0) + e.amount;
      e.shareByUid.forEach((u, v) => share[u] = (share[u] ?? 0) + v);
    }
    final byCat = <String, double>{};
    for (final e in spending) {
      final name = e.category.isEmpty ? 'Other' : e.category;
      byCat[name] = (byCat[name] ?? 0) + e.amount;
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final people = {...members, ...net.keys}.toList()..sort((a, b) => nameOf(a).compareTo(nameOf(b)));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _header(groupName, 'Group report · ${_day.format(DateTime.now())}'),
      footer: _footer,
      build: (_) => [
        _statRow([
          ('Total spent', rs(total)),
          ('Expenses', '${spending.length}'),
          ('Payments', '${payments.length}'),
        ]),
        pw.SizedBox(height: 18),
        _title('Who owes whom'),
        debts.isEmpty
            ? pw.Text('Everyone is settled up.', style: pw.TextStyle(color: _muted))
            : _table(
                ['From', 'To', 'Amount'],
                [for (final d in debts) [nameOf(d.fromUid), nameOf(d.toUid), rs(d.amount)]],
                align: const [pw.Alignment.centerLeft, pw.Alignment.centerLeft, pw.Alignment.centerRight],
              ),
        pw.SizedBox(height: 18),
        _title('Members'),
        _table(
          ['Member', 'Paid', 'Share', 'Net'],
          [
            for (final u in people)
              [nameOf(u), rs(paid[u] ?? 0), rs(share[u] ?? 0), rs(net[u] ?? 0)],
          ],
          align: const [
            pw.Alignment.centerLeft,
            pw.Alignment.centerRight,
            pw.Alignment.centerRight,
            pw.Alignment.centerRight,
          ],
        ),
        pw.SizedBox(height: 18),
        _title('By category'),
        _table(
          ['Category', 'Amount'],
          [for (final c in cats) [c.key, rs(c.value)]],
          align: const [pw.Alignment.centerLeft, pw.Alignment.centerRight],
        ),
        pw.SizedBox(height: 18),
        _title('Ledger'),
        _table(
          ['Date', 'Description', 'Paid by', 'Amount'],
          [
            for (final e in expenses)
              [
                _day.format(e.date),
                e.isPayment ? 'Payment to ${nameOf(e.paymentRecipient ?? '')}' : e.description,
                nameOf(e.payerUid),
                rs(e.amount),
              ],
          ],
          align: const [
            pw.Alignment.centerLeft,
            pw.Alignment.centerLeft,
            pw.Alignment.centerLeft,
            pw.Alignment.centerRight,
          ],
        ),
      ],
    ));
    final file = await _write('${groupName}_report.pdf', await doc.save());
    await _share(file, '$groupName — SplitMate report');
  }

  // ── PDF building blocks ───────────────────────────────────────────────────

  static pw.Widget _header(String title, String subtitle) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        margin: const pw.EdgeInsets.only(bottom: 16),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _soft, width: 2))),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(subtitle, style: pw.TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ),
            pw.Text('SplitMate', style: pw.TextStyle(color: _violet, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _footer(pw.Context ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(color: _muted, fontSize: 9)),
      );

  static pw.Widget _title(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _statRow(List<(String, String)> stats) => pw.Row(
        children: [
          for (final s in stats)
            pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.only(right: 8),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(s.$1, style: pw.TextStyle(color: _muted, fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text(s.$2, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      );

  static pw.Widget _table(List<String> headers, List<List<String>> rows,
      {required List<pw.Alignment> align}) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: pw.BoxDecoration(color: _violet),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      oddRowDecoration: pw.BoxDecoration(color: _soft),
      cellAlignments: {for (var i = 0; i < align.length; i++) i: align[i]},
      headerAlignments: {for (var i = 0; i < align.length; i++) i: align[i]},
      border: null,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }
}
