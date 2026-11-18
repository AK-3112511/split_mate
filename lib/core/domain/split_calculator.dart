import '../utils/money.dart';

/// How a group expense is divided.
enum SplitMode {
  equal('equal', 'Equally'),
  exact('custom', 'Exact amounts'),
  percent('percentage', 'Percentages'),
  itemized('itemized', 'Itemized');

  /// Value persisted in Firestore (kept compatible with v1 data).
  final String storageKey;
  final String label;
  const SplitMode(this.storageKey, this.label);

  static SplitMode fromStorage(String? key) => SplitMode.values.firstWhere(
        (m) => m.storageKey == key,
        orElse: () => SplitMode.equal,
      );
}

/// One line of an itemized bill.
class SplitItem {
  final String name;
  final double amount;
  final List<String> memberUids;
  const SplitItem({required this.name, required this.amount, required this.memberUids});
}

/// Outcome of a split calculation. Amounts are rounded to paise and, when
/// [isValid], always sum exactly to [total].
class SplitResult {
  final Map<String, double> shares;
  final double total;
  final String? error;

  /// Positive = still to assign, negative = over-assigned (exact / percent).
  final double remaining;

  const SplitResult._(this.shares, this.total, this.error, this.remaining);

  factory SplitResult.ok(Map<String, double> shares, double total) =>
      SplitResult._(Map.unmodifiable(shares), total, null, 0);

  factory SplitResult.invalid(String error, {double total = 0, double remaining = 0}) =>
      SplitResult._(const {}, total, error, remaining);

  bool get isValid => error == null;
}

/// Pure, deterministic split engine. All maths in integer paise.
///
/// Rounding rule: when an amount can't be divided evenly, the leftover paise go
/// to the payer if they take part in the split, otherwise to the first
/// participant (stable order). This keeps every split summing exactly to total.
class SplitCalculator {
  SplitCalculator._();

  static SplitResult equal({
    required double total,
    required List<String> participants,
    required String payerUid,
  }) {
    final totalPaise = Money.toPaise(total);
    if (totalPaise <= 0) return SplitResult.invalid('Enter an amount');
    final people = _unique(participants);
    if (people.isEmpty) return SplitResult.invalid('Pick at least one person', total: total);

    final base = totalPaise ~/ people.length;
    final remainder = totalPaise % people.length;
    final shares = <String, int>{for (final uid in people) uid: base};
    if (remainder > 0) {
      final receiver = people.contains(payerUid) ? payerUid : people.first;
      shares[receiver] = shares[receiver]! + remainder;
    }
    return SplitResult.ok(_toRupees(shares), Money.fromPaise(totalPaise));
  }

  static SplitResult exact({
    required double total,
    required Map<String, double> amounts,
  }) {
    final totalPaise = Money.toPaise(total);
    if (totalPaise <= 0) return SplitResult.invalid('Enter an amount');
    final shares = <String, int>{};
    var sum = 0;
    for (final entry in amounts.entries) {
      final p = Money.toPaise(entry.value);
      if (entry.value.isNaN || entry.value.isInfinite) {
        return SplitResult.invalid('Amounts must be numbers', total: total);
      }
      if (p < 0) return SplitResult.invalid('Amounts can\'t be negative', total: total);
      if (p == 0) continue;
      shares[entry.key] = p;
      sum += p;
    }
    if (shares.isEmpty) {
      return SplitResult.invalid('Assign the amount to at least one person',
          total: total, remaining: total);
    }
    final diff = totalPaise - sum;
    if (diff != 0) {
      final remaining = Money.fromPaise(diff);
      return SplitResult.invalid(
        diff > 0
            ? '${Money.format(remaining)} left to assign'
            : '${Money.format(-remaining)} over the total',
        total: total,
        remaining: remaining,
      );
    }
    return SplitResult.ok(_toRupees(shares), Money.fromPaise(totalPaise));
  }

  /// [percents] are whole or decimal percentages (e.g. 33.33). Must sum to 100.
  static SplitResult percent({
    required double total,
    required Map<String, double> percents,
    required String payerUid,
  }) {
    final totalPaise = Money.toPaise(total);
    if (totalPaise <= 0) return SplitResult.invalid('Enter an amount');

    // Work in basis points (1% = 100) to avoid float drift.
    final bps = <String, int>{};
    var sumBps = 0;
    for (final entry in percents.entries) {
      if (entry.value.isNaN || entry.value.isInfinite) {
        return SplitResult.invalid('Percentages must be numbers', total: total);
      }
      final b = (entry.value * 100).round();
      if (b < 0) return SplitResult.invalid('Percentages can\'t be negative', total: total);
      if (b == 0) continue;
      bps[entry.key] = b;
      sumBps += b;
    }
    if (bps.isEmpty) {
      return SplitResult.invalid('Give at least one person a percentage', total: total);
    }
    if (sumBps != 10000) {
      final left = (10000 - sumBps) / 100;
      return SplitResult.invalid(
        left > 0 ? '${_pct(left)}% left to assign' : '${_pct(-left)}% over 100%',
        total: total,
        remaining: Money.fromPaise((totalPaise * (10000 - sumBps)) ~/ 10000),
      );
    }

    final shares = <String, int>{};
    var assigned = 0;
    for (final entry in bps.entries) {
      final p = (totalPaise * entry.value) ~/ 10000;
      shares[entry.key] = p;
      assigned += p;
    }
    final leftover = totalPaise - assigned;
    if (leftover != 0) {
      final receiver = shares.containsKey(payerUid)
          ? payerUid
          : (shares.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
      shares[receiver] = shares[receiver]! + leftover;
    }
    return SplitResult.ok(_toRupees(shares), Money.fromPaise(totalPaise));
  }

  /// [extra] is tax / service charge minus any discount for the whole bill
  /// (may be negative). It's shared in proportion to each person's items.
  static SplitResult itemized({
    required List<SplitItem> items,
    required String payerUid,
    double extra = 0,
  }) {
    if (items.isEmpty) return SplitResult.invalid('Add at least one item');
    final shares = <String, int>{};
    var totalPaise = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final label = item.name.trim().isEmpty ? 'Item ${i + 1}' : '"${item.name.trim()}"';
      final itemPaise = Money.toPaise(item.amount);
      if (itemPaise <= 0) return SplitResult.invalid('$label needs a price');
      final people = _unique(item.memberUids);
      if (people.isEmpty) return SplitResult.invalid('Pick who shares $label');

      final base = itemPaise ~/ people.length;
      final remainder = itemPaise % people.length;
      for (final uid in people) {
        shares[uid] = (shares[uid] ?? 0) + base;
      }
      if (remainder > 0) {
        final receiver = people.contains(payerUid) ? payerUid : people.first;
        shares[receiver] = shares[receiver]! + remainder;
      }
      totalPaise += itemPaise;
    }

    final extraPaise = extra.isFinite ? Money.toPaise(extra) : 0;
    if (extraPaise != 0) {
      if (totalPaise + extraPaise <= 0) return SplitResult.invalid('The discount is more than the bill');
      final itemsPaise = totalPaise;
      var allocated = 0;
      for (final uid in shares.keys.toList()) {
        // ~/ truncates toward zero, so a discount never takes more than a share.
        final part = (extraPaise * shares[uid]!) ~/ itemsPaise;
        shares[uid] = shares[uid]! + part;
        allocated += part;
      }
      final leftover = extraPaise - allocated;
      if (leftover != 0) {
        final receiver = shares.containsKey(payerUid)
            ? payerUid
            : (shares.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
        shares[receiver] = shares[receiver]! + leftover;
      }
      totalPaise += extraPaise;
    }

    if (Money.fromPaise(totalPaise) > Money.maxAmount) {
      return SplitResult.invalid('Total is too large');
    }
    return SplitResult.ok(_toRupees(shares), Money.fromPaise(totalPaise));
  }

  /// Derives display percentages from stored amounts (used when re-opening an
  /// expense for editing). Rounded to 2 decimals; the last entry absorbs drift
  /// so the result always sums to exactly 100.
  static Map<String, double> percentsFromShares(Map<String, double> shares, double total) {
    final totalPaise = Money.toPaise(total);
    if (totalPaise <= 0 || shares.isEmpty) return {};
    final keys = shares.keys.toList();
    final out = <String, double>{};
    var sumBps = 0;
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      if (i == keys.length - 1) {
        out[k] = (10000 - sumBps) / 100;
      } else {
        final b = (Money.toPaise(shares[k]!) * 10000 / totalPaise).round();
        out[k] = b / 100;
        sumBps += b;
      }
    }
    return out;
  }

  static List<String> _unique(List<String> uids) {
    final seen = <String>{};
    return [for (final u in uids) if (u.isNotEmpty && seen.add(u)) u];
  }

  static Map<String, double> _toRupees(Map<String, int> paise) =>
      {for (final e in paise.entries) if (e.value > 0) e.key: Money.fromPaise(e.value)};

  static String _pct(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
