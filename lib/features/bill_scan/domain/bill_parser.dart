import 'dart:math' as math;
import '../../../core/utils/money.dart';

/// One line of text read from the photo, with its box in image pixels.
class OcrLine {
  final String text;
  final double left, top, right, bottom;

  /// Tilt of the line in degrees (clockwise positive), as ML Kit reports it.
  final double angle;
  const OcrLine(
    this.text, {
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.angle = 0,
  });

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

class BillItem {
  final String name;

  /// Null when the price was there but OCR couldn't read it: the item is kept
  /// so you fill the price in, rather than silently dropped.
  final double? amount;
  const BillItem(this.name, this.amount);

  @override
  String toString() => '$name: $amount';
}

/// What was read off a restaurant / shop bill.
class ParsedBill {
  final List<BillItem> items;

  /// Taxes and charges (GST, service charge, packing…) incl. round-off. ≥ 0.
  final double charges;

  /// Discounts. ≥ 0.
  final double discount;

  /// The total printed on the bill, if one was found.
  final double? billTotal;

  /// Best guess at the restaurant / shop name.
  final String? merchant;

  const ParsedBill({required this.items, this.charges = 0, this.discount = 0, this.billTotal, this.merchant});

  double get itemsTotal => Money.fromPaise(items.fold<int>(0, (a, i) => a + Money.toPaise(i.amount ?? 0)));

  /// Net extra on top of the items (charges − discount).
  double get extra => Money.fromPaise(Money.toPaise(charges) - Money.toPaise(discount));

  double get total => Money.fromPaise(Money.toPaise(itemsTotal) + Money.toPaise(extra));

  bool get isEmpty => items.isEmpty;

  /// True when items + charges − discount equals the printed total.
  bool get matchesBill => billTotal != null && items.every((i) => i.amount != null) && Money.equals(total, billTotal!);
}

/// Reads items, charges and the total from OCR lines of a bill.
///
/// Bills print columns (item · qty · rate · amount) that OCR returns as
/// separate lines, so lines are first regrouped into rows by their vertical
/// position, then each row is read right to left: the last number is the
/// amount, the words before it are the name.
class BillParser {
  BillParser._();

  static ParsedBill parse(List<OcrLine> lines) {
    final rows = groupRows(lines);
    final items = <BillItem>[];
    var charges = 0;
    var discount = 0;
    int? subtotal;
    final totals = <({int paise, bool strong})>[];
    String? pendingName;
    var itemsOver = false;

    /// After "Grand total" bills often repeat the GST split; don't count it twice.
    var finalTotalSeen = false;
    var headerRow = -1;

    for (var r = 0; r < rows.length; r++) {
      final text = rows[r];
      final lower = text.toLowerCase();
      final (:name, :numbers, :garbled) = splitRow(text);
      final kind = _classify(lower);

      if (kind == _Kind.header) {
        headerRow = r;
        items.clear(); // anything "above the header" was address / bill info
        pendingName = null;
        continue;
      }
      if (kind == _Kind.skip) {
        pendingName = null;
        continue;
      }
      if (numbers.isEmpty && !garbled) {
        // A wrapped item name, a section heading ("MAIN COURSE"), or the shop's address.
        if (!itemsOver && _letters(name) >= 2) pendingName = name;
        continue;
      }
      if (finalTotalSeen && kind != _Kind.total) continue;
      // The amount on this row; null when it's there but unreadable.
      final int? amount = garbled ? null : Money.toPaise(numbers.last);
      switch (kind) {
        case _Kind.subtotal:
          if (amount != null) subtotal = amount;
          itemsOver = true;
        case _Kind.charge:
          if (amount != null) charges += amount;
          itemsOver = true;
        case _Kind.roundOff:
          if (amount != null) charges += _isNegative(text) ? -amount : amount;
          itemsOver = true;
        case _Kind.discount:
          if (amount != null) discount += amount;
          itemsOver = true;
        case _Kind.total:
          if (amount != null) {
            final strong = _strongTotal.any(lower.contains);
            totals.add((paise: amount, strong: strong));
            // A plain "Total" printed before the taxes is the subtotal.
            if (!strong && charges == 0 && discount == 0) subtotal ??= amount;
            if (strong) finalTotalSeen = true;
          }
          itemsOver = true;
        case _Kind.item:
          // Unreadable amount: qty × rate still gives it ("4  60.00  24?.?0").
          final qtyRate = garbled ? _qtyTimesRate(numbers) : null;
          final price = amount ?? qtyRate?.paise;
          if (itemsOver || (price != null && (price <= 0 || price > _maxItemPaise))) {
            pendingName = null;
            continue;
          }
          var itemName = name;
          if (_letters(itemName) < 2 && pendingName != null) {
            itemName = pendingName;
          } else if (pendingName != null && (itemName.startsWith('(') || itemName.startsWith('-'))) {
            itemName = '$pendingName $itemName';
          }
          pendingName = null;
          if (_letters(itemName) < 2) continue;
          final qty = garbled ? qtyRate?.qty : _quantity(numbers);
          items.add(BillItem(_tidyName(itemName, qty), price == null ? null : Money.fromPaise(price)));
        default:
          break;
      }
    }

    // Shop name: the tallest text near the top, before the items.
    final merchant = _merchant(lines, headerRow >= 0);

    int? billTotal;
    if (totals.isNotEmpty) {
      final strong = totals.where((t) => t.strong).toList();
      billTotal = (strong.isNotEmpty ? strong.last : totals.last).paise;
    }

    // One unreadable price and a printed subtotal: the price is the gap.
    final unread = items.where((i) => i.amount == null).toList();
    if (unread.length == 1 && subtotal != null) {
      final known = items.fold<int>(0, (a, i) => a + Money.toPaise(i.amount ?? 0));
      if (subtotal > known && subtotal - known <= _maxItemPaise) {
        final at = items.indexOf(unread.single);
        items[at] = BillItem(unread.single.name, Money.fromPaise(subtotal - known));
      }
    }

    // Reconcile: when items + read charges are within a rupee of the printed
    // total, put the difference down to rounding so it adds up exactly.
    final itemsPaise = items.fold<int>(0, (a, i) => a + Money.toPaise(i.amount ?? 0));
    if (billTotal != null && items.isNotEmpty && items.every((i) => i.amount != null)) {
      final diff = billTotal - (itemsPaise + charges - discount);
      if (diff.abs() <= 100) {
        charges += diff;
      } else if (subtotal != null && subtotal == itemsPaise) {
        // Items are right; a charge line was misread. Trust the printed total.
        final extra = billTotal - itemsPaise;
        charges = extra > 0 ? extra : 0;
        discount = extra < 0 ? -extra : 0;
      }
    }
    if (charges < 0) {
      discount -= charges;
      charges = 0;
    }

    return ParsedBill(
      items: items,
      charges: Money.fromPaise(charges),
      discount: Money.fromPaise(discount),
      billTotal: billTotal == null ? null : Money.fromPaise(billTotal),
      merchant: merchant,
    );
  }

  /// Joins OCR lines that sit on the same printed row, top to bottom, each
  /// row's pieces left to right.
  static List<String> groupRows(List<OcrLine> lines) {
    final kept = lines.where((l) => l.text.trim().isNotEmpty).toList();
    if (kept.isEmpty) return const [];
    // Undo the photo's tilt (median line angle) so a row's pieces line up.
    final angles = kept.map((l) => l.angle).toList()..sort();
    final slope = math.tan(angles[angles.length ~/ 2] * math.pi / 180);
    double y(OcrLine l) => l.centerY - l.centerX * slope;
    final sorted = kept..sort((a, b) => y(a).compareTo(y(b)));
    final heights = sorted.map((l) => l.height).toList()..sort();
    final tolerance = heights[heights.length ~/ 2] * 0.6;
    final rows = <List<OcrLine>>[];
    for (final line in sorted) {
      final row = rows.isEmpty ? null : rows.last;
      if (row != null) {
        final rowY = row.map(y).reduce((a, b) => a + b) / row.length;
        if ((y(line) - rowY).abs() <= tolerance) {
          row.add(line);
          continue;
        }
      }
      rows.add([line]);
    }
    return [
      for (final row in rows) (row..sort((a, b) => a.left.compareTo(b.left))).map((l) => l.text.trim()).join('  '),
    ];
  }

  /// Splits "2 Butter Naan  2  60.00  120.00" into the name and the trailing
  /// numbers. [garbled] means the last token was clearly a number OCR mangled.
  static ({String name, List<double> numbers, bool garbled}) splitRow(String text) {
    final tokens = text.trim().split(RegExp(r'\s+'));
    final numbers = <double>[];
    var garbled = false;
    if (tokens.length > 1 && _number(tokens.last) == null && _looksLikeAmount(tokens.last)) {
      tokens.removeLast();
      garbled = true;
    }
    while (tokens.isNotEmpty) {
      final n = _number(tokens.last);
      if (n == null) {
        if (_filler.contains(tokens.last.toLowerCase())) {
          tokens.removeLast();
          continue;
        }
        break;
      }
      numbers.insert(0, n);
      tokens.removeLast();
    }
    // Leading serial number or quantity ("1.", "2", "01)").
    while (tokens.isNotEmpty && RegExp(r'^\d{1,2}[.)]?$').hasMatch(tokens.first)) {
      tokens.removeAt(0);
    }
    return (name: tokens.join(' ').trim(), numbers: numbers, garbled: garbled);
  }

  /// Two or more digits with a decimal point, but not a date, time or rate.
  static bool _looksLikeAmount(String t) =>
      RegExp(r'\d.*[.,].*\d|\d.*\d.*[.,]').hasMatch(t) && !RegExp(r'[%:/]').hasMatch(t);

  static ({int qty, int paise})? _qtyTimesRate(List<double> n) {
    if (n.length < 2) return null;
    final qty = n[n.length - 2], rate = n.last;
    if (qty != qty.roundToDouble() || qty < 1 || qty > 50) return null;
    return (qty: qty.toInt(), paise: Money.toPaise(qty * rate));
  }

  static final _numberRe = RegExp(r'^\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?$|^\d{1,7}(?:\.\d{1,2})?$');

  /// "1,240.00", "240", "₹240", "Rs.240", "240/-", "24O.00" (OCR O for 0).
  static double? _number(String raw) {
    var t = raw.trim();
    t = t.replaceFirst(RegExp(r'^(?:₹|rs\.?|inr)', caseSensitive: false), '');
    t = t.replaceFirst(RegExp(r'/-$'), '');
    t = t.replaceAll(RegExp(r'^[(\-]+|[)]+$'), '');
    if (!RegExp(r'\d').hasMatch(t)) return null;
    if (RegExp(r'^[\dOo.,]+$').hasMatch(t)) t = t.replaceAll(RegExp('[Oo]'), '0');
    // Other OCR look-alikes inside a price: l20.00, 1,2S0, 4B0.
    if (RegExp(r'\d').allMatches(t).length >= 2 && RegExp(r'^[\d.,OoQDlI|SsBZz]+$').hasMatch(t)) {
      t = t.replaceAllMapped(RegExp('[OoQDlI|SsBZz]'), (m) => _lookalikes[m[0]]!);
    }
    // A stray letter in the last decimal place: "240.0e".
    t = t.replaceFirstMapped(RegExp(r'^(\d[\d,]*\.\d)[A-Za-z]$'), (m) => '${m[1]}0');
    if (!_numberRe.hasMatch(t)) return null;
    return double.tryParse(t.replaceAll(',', ''));
  }

  static const _lookalikes = {
    'O': '0', 'o': '0', 'Q': '0', 'D': '0', 'l': '1', 'I': '1', '|': '1', //
    'S': '5', 's': '5', 'B': '8', 'Z': '2', 'z': '2',
  };

  static const _filler = {'x', '@', 'nos', 'no', 'pcs', 'pc', 'qty', 'rs', 'rs.', 'inr', '₹', '-', ':', '=', '/-'};

  static const _maxItemPaise = 100000 * 100;

  static int _letters(String s) => RegExp('[A-Za-z]').allMatches(s).length;

  static bool _isNegative(String text) => RegExp(r'-\s*[\d₹]|\(\s*[\d₹]').hasMatch(text);

  /// Quantity when the row reads qty · rate · amount and they agree.
  static int? _quantity(List<double> n) {
    if (n.length < 3) return null;
    final qty = n[n.length - 3], rate = n[n.length - 2], amount = n.last;
    if (qty != qty.roundToDouble() || qty < 2 || qty > 50) return null;
    return Money.equals(qty * rate, amount) ? qty.toInt() : null;
  }

  static String _tidyName(String name, int? qty) {
    var s = name.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[-*•.:]+|[-*•.:]+$'), '').trim();
    if (s == s.toUpperCase()) s = _titleCase(s);
    if (s.length > 50) s = s.substring(0, 50).trim();
    return qty == null ? s : '$s ×$qty';
  }

  static String _titleCase(String s) =>
      s.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  static String? _merchant(List<OcrLine> lines, bool hadHeader) {
    if (lines.isEmpty) return null;
    final sorted = [...lines]..sort((a, b) => a.top.compareTo(b.top));
    final top = sorted.take(5).where((l) {
      final lower = l.text.toLowerCase();
      return _letters(l.text) >= 3 &&
          RegExp(r'\d').allMatches(l.text).length <= 2 &&
          _classify(lower) == _Kind.item &&
          !_notMerchant.any(lower.contains);
    }).toList();
    if (top.isEmpty) return null;
    top.sort((a, b) => b.height.compareTo(a.height));
    final name = _tidyName(top.first.text, null);
    return name.length < 3 ? null : name;
  }

  static const _notMerchant = ['invoice', 'receipt', 'bill', 'estimate', 'order', 'welcome', 'kot', 'copy'];

  static const _strongTotal = ['grand', 'net', 'payable', 'to pay', 'bill amount', 'total amount', 'amount due'];

  static _Kind _classify(String lower) {
    bool has(List<String> phrases) => phrases.any(lower.contains);
    // Whole words only: "vegetable" isn't a table number, "cashew" isn't cash.
    final padded = ' ${lower.replaceAll(RegExp(r'[^a-z0-9%]+'), ' ')} ';
    bool word(List<String> words) => words.any((w) => padded.contains(' $w '));

    if (word(['item', 'items', 'particulars', 'description']) &&
        word(['qty', 'quantity', 'amount', 'amt', 'price', 'rate', 'total'])) {
      return _Kind.header;
    }
    if (has(['total qty', 'total items', 'total item', 'no of items', 'item count', 'total quantity'])) {
      return _Kind.skip;
    }
    if (has(['round off', 'roundoff', 'round-off', 'rounding', 'r/off', 'r.off', 'rnd off'])) return _Kind.roundOff;
    if (has([
          'sub total',
          'subtotal',
          'sub-total',
          'food total',
          'item total',
          'gross amount',
          'gross total',
          'basic amount',
          'total before',
        ]) ||
        word(['taxable'])) {
      return _Kind.subtotal;
    }
    if (word(['discount', 'disc', 'offer', 'promo', 'coupon', 'savings'])) return _Kind.discount;
    if (word([
          'cgst',
          'sgst',
          'igst',
          'utgst',
          'gst',
          'vat',
          'cess',
          'tax',
          'taxes',
          'tip',
          'packing',
          'packaging',
          'delivery',
          'container',
        ]) ||
        has(['service charge', 'service tax', 'serv chg', 'svc chg', 's.c.', 'serv. ch', 'service ch'])) {
      return _Kind.charge;
    }
    if (word(['total']) ||
        has(['net amount', 'amount payable', 'net payable', 'bill amount', 'to pay', 'amount due'])) {
      return _Kind.total;
    }
    if (word([
          'gstin',
          'fssai',
          'invoice',
          'table',
          'tbl',
          'cashier',
          'waiter',
          'steward',
          'captain',
          'date',
          'time',
          'phone',
          'ph',
          'mob',
          'mobile',
          'tel',
          'www',
          'com',
          'thank',
          'thanks',
          'pax',
          'covers',
          'kot',
          'token',
          'hsn',
          'sac',
          'cin',
          'upi',
          'card',
          'cash',
          'change',
          'tender',
          'paid',
          'balance',
          'customer',
          'guest',
          'server',
          'terminal',
          'counter',
          'gpay',
          'paytm',
          'phonepe',
        ]) ||
        has(['gst no', 'bill no', 'bill #', 'order no', 'order #', 'visit again', 'pan no', 'e & o', 'e&o'])) {
      return _Kind.skip;
    }
    return _Kind.item;
  }
}

enum _Kind { item, header, skip, subtotal, charge, roundOff, discount, total }
