import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/bill_scan/domain/bill_parser.dart';

/// Builds OCR lines the way ML Kit returns them: one line per column piece.
/// Each row is a list of (text, x) pieces; rows are 30px apart, 20px tall.
/// [skew] moves pieces down by that many px per 100px to the right.
List<OcrLine> bill(List<List<(String, double)>> rows, {double skew = 0, double titleHeight = 20}) {
  final out = <OcrLine>[];
  for (var r = 0; r < rows.length; r++) {
    for (final (text, x) in rows[r]) {
      final h = r == 0 ? titleHeight : 20.0;
      final y = 40.0 + r * 30 + x / 100 * skew;
      final angle = math.atan(skew / 100) * 180 / math.pi;
      out.add(OcrLine(text, left: x, top: y, right: x + text.length * 9, bottom: y + h, angle: angle));
    }
  }
  // ML Kit tends to return column blocks, not rows: shuffle the order.
  out.sort((a, b) => a.left.compareTo(b.left));
  return out;
}

void main() {
  test('typical GST restaurant bill', () {
    final b = BillParser.parse(
      bill([
        [('TOIT BREWPUB', 120)],
        [('100 Feet Road, Indiranagar', 80)],
        [('GSTIN: 29ABCDE1234F1Z5', 80)],
        [('Bill No: 4521', 10), ('Date: 18/11/26', 300)],
        [('Table: 12', 10), ('Pax: 4', 300)],
        [('Item', 10), ('Qty', 250), ('Rate', 320), ('Amount', 400)],
        [('Paneer Tikka', 10), ('1', 250), ('320.00', 320), ('320.00', 400)],
        [('Butter Naan', 10), ('4', 250), ('60.00', 320), ('240.00', 400)],
        [('Dal Makhani', 10), ('1', 250), ('280.00', 320), ('280.00', 400)],
        [('Fresh Lime Soda', 10), ('2', 250), ('90.00', 320), ('180.00', 400)],
        [('Sub Total', 10), ('1,020.00', 400)],
        [('CGST @ 2.5%', 10), ('25.50', 400)],
        [('SGST @ 2.5%', 10), ('25.50', 400)],
        [('Service Charge 5%', 10), ('51.00', 400)],
        [('Grand Total', 10), ('₹1,122.00', 400)],
        [('Thank you! Visit again', 60)],
      ], titleHeight: 34),
    );

    expect(b.items.map((i) => i.name), ['Paneer Tikka', 'Butter Naan ×4', 'Dal Makhani', 'Fresh Lime Soda ×2']);
    expect(b.items.map((i) => i.amount), [320, 240, 280, 180]);
    expect(b.charges, 102);
    expect(b.discount, 0);
    expect(b.billTotal, 1122);
    expect(b.matchesBill, isTrue);
    expect(b.merchant, 'Toit Brewpub');
  });

  test('vegetable / cashew / cardamom items are not mistaken for bill info', () {
    final b = BillParser.parse(
      bill([
        [('Vegetable Biryani', 10), ('250', 400)],
        [('Kaju (Cashew) Curry', 10), ('310', 400)],
        [('Cardamom Tea', 10), ('40', 400)],
        [('Total', 10), ('600', 400)],
      ]),
    );
    expect(b.items.map((i) => i.name), ['Vegetable Biryani', 'Kaju (Cashew) Curry', 'Cardamom Tea']);
    expect(b.matchesBill, isTrue);
  });

  test('slightly tilted photo still pairs names with amounts', () {
    // 8px per 100px: the price sits ~a full row lower than its name.
    final b = BillParser.parse(
      bill([
        [('Masala Dosa', 10), ('120.00', 400)],
        [('Filter Coffee', 10), ('60.00', 400)],
        [('Total', 10), ('180.00', 400)],
      ], skew: 8),
    );
    expect(b.items.map((i) => '${i.name}=${i.amount}'), ['Masala Dosa=120.0', 'Filter Coffee=60.0']);
    expect(b.billTotal, 180);
  });

  test('wrapped names, section headings and OCR noise', () {
    final b = BillParser.parse(
      bill([
        [('MAIN COURSE', 10)],
        [('Paneer Butter Masala', 10)],
        [('(Half)', 10), ('1', 250), ('220.00', 400)],
        [('2', 10), ('Garlic Naan', 40), ('1OO.OO', 400)],
        [('Chicken 65', 10), ('260/-', 400)],
        [('Total', 10), ('Rs. 580', 400)],
      ]),
    );
    expect(b.items.map((i) => i.name), ['Paneer Butter Masala (Half)', 'Garlic Naan', 'Chicken']);
    expect(b.items.map((i) => i.amount), [220, 100, 260]);
    expect(b.matchesBill, isTrue);
  });

  test('discount and negative round-off', () {
    final b = BillParser.parse(
      bill([
        [('Pizza Margherita', 10), ('450.00', 400)],
        [('Garlic Bread', 10), ('180.00', 400)],
        [('Discount 10%', 10), ('-63.00', 400)],
        [('GST 5%', 10), ('28.35', 400)],
        [('Round Off', 10), ('-0.35', 400)],
        [('Net Amount', 10), ('595.00', 400)],
      ]),
    );
    expect(b.items.length, 2);
    expect(b.discount, 63);
    expect(b.charges, 28);
    expect(b.total, 595);
    expect(b.matchesBill, isTrue);
  });

  test('small rounding gap is absorbed so the total matches', () {
    final b = BillParser.parse(
      bill([
        [('Cold Coffee', 10), ('149.00', 400)],
        [('Sandwich', 10), ('129.00', 400)],
        [('CGST', 10), ('6.95', 400)],
        [('SGST', 10), ('6.95', 400)],
        [('Total', 10), ('292.00', 400)],
      ]),
    );
    expect(b.charges, 14);
    expect(b.matchesBill, isTrue);
  });

  test('GST summary printed after the grand total is not counted twice', () {
    final b = BillParser.parse(
      bill([
        [('Thali', 10), ('300.00', 400)],
        [('CGST 2.5%', 10), ('7.50', 400)],
        [('SGST 2.5%', 10), ('7.50', 400)],
        [('Grand Total', 10), ('315.00', 400)],
        [('CGST 2.5% on 300.00', 10), ('7.50', 400)],
        [('SGST 2.5% on 300.00', 10), ('7.50', 400)],
        [('Paid by UPI', 10), ('315.00', 400)],
      ]),
    );
    expect(b.charges, 15);
    expect(b.matchesBill, isTrue);
  });

  test('a misread tax line falls back to the printed total when items match the subtotal', () {
    final b = BillParser.parse(
      bill([
        [('Burger', 10), ('200.00', 400)],
        [('Fries', 10), ('100.00', 400)],
        [('Sub Total', 10), ('300.00', 400)],
        [('CGST', 10), ('75.00', 400)], // really 7.50
        [('SGST', 10), ('7.50', 400)],
        [('Grand Total', 10), ('315.00', 400)],
      ]),
    );
    expect(b.charges, 15);
    expect(b.matchesBill, isTrue);
  });

  test('a missed line is reported, not hidden', () {
    final b = BillParser.parse(
      bill([
        [('Momos', 10), ('150.00', 400)],
        [('Grand Total', 10), ('400.00', 400)],
      ]),
    );
    expect(b.items.length, 1);
    expect(b.billTotal, 400);
    expect(b.matchesBill, isFalse);
  });

  test('nothing readable', () {
    expect(BillParser.parse(const []).isEmpty, isTrue);
    expect(
      BillParser.parse(
        bill([
          [('Thank you', 10)],
        ]),
      ).isEmpty,
      isTrue,
    );
  });

  test('row splitting', () {
    final naan = BillParser.splitRow('2 Butter Naan  2  60.00  120.00');
    expect(naan.name, 'Butter Naan');
    expect(naan.numbers, [2.0, 60.0, 120.0]);
    final total = BillParser.splitRow('Grand Total : ₹ 1,234.50');
    expect(total.name, 'Grand Total');
    expect(total.numbers, [1234.5]);
    expect(BillParser.splitRow('CGST @ 2.5% 31.00').numbers, [31.0]);
  });
}
