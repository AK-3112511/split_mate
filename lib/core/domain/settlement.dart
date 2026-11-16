import '../utils/money.dart';

/// Minimal view of an expense the balance maths needs. Group expense models
/// implement this so the algorithm stays pure and easy to test.
abstract class LedgerEntry {
  String get payerUid;
  double get amount;

  /// uid → amount that person consumed (owes the payer).
  Map<String, double> get shareByUid;
  bool get isDeleted;
}

/// A suggested or recorded transfer.
class Transfer {
  final String fromUid;
  final String toUid;
  final double amount;
  const Transfer(this.fromUid, this.toUid, this.amount);

  @override
  String toString() => 'Transfer($fromUid → $toUid: $amount)';
}

/// Pure settlement maths for a group.
class Settlement {
  Settlement._();

  /// Net balance per person: positive = others owe them, negative = they owe.
  /// Always sums to zero (to the paisa) across everyone appearing in [entries].
  static Map<String, double> netBalances(
    Iterable<LedgerEntry> entries, {
    Iterable<String> members = const [],
  }) {
    final paise = <String, int>{for (final m in members) m: 0};
    for (final e in entries) {
      if (e.isDeleted) continue;
      final shares = e.shareByUid;
      final sharePaise = <String, int>{
        for (final s in shares.entries) s.key: Money.toPaise(s.value),
      };
      // Credit the payer with exactly what others consumed so the sum is 0
      // even if a legacy document's amount drifted from its splits.
      final totalShares = sharePaise.values.fold<int>(0, (a, b) => a + b);
      paise[e.payerUid] = (paise[e.payerUid] ?? 0) + totalShares;
      sharePaise.forEach((uid, p) => paise[uid] = (paise[uid] ?? 0) - p);
    }
    return {for (final e in paise.entries) e.key: Money.fromPaise(e.value)};
  }

  /// Greedy minimum-transfer suggestion ("Simplify debts").
  static List<Transfer> simplify(Map<String, double> net) {
    final creditors = <_Bal>[];
    final debtors = <_Bal>[];
    net.forEach((uid, v) {
      final p = Money.toPaise(v);
      if (p > 0) creditors.add(_Bal(uid, p));
      if (p < 0) debtors.add(_Bal(uid, -p));
    });
    final out = <Transfer>[];
    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      creditors.sort((a, b) => b.paise.compareTo(a.paise));
      debtors.sort((a, b) => b.paise.compareTo(a.paise));
      final cr = creditors.first;
      final db = debtors.first;
      final amt = cr.paise < db.paise ? cr.paise : db.paise;
      out.add(Transfer(db.uid, cr.uid, Money.fromPaise(amt)));
      cr.paise -= amt;
      db.paise -= amt;
      if (cr.paise == 0) creditors.removeAt(0);
      if (db.paise == 0) debtors.removeAt(0);
    }
    return out;
  }

  /// Real person-to-person balances built only from expenses those two people
  /// actually shared (plus payments between them). Key is the *other* person,
  /// value is from [me]'s point of view: positive = they owe me.
  static Map<String, double> pairwiseFor(String me, Iterable<LedgerEntry> entries) {
    final paise = <String, int>{};
    for (final e in entries) {
      if (e.isDeleted) continue;
      final payer = e.payerUid;
      e.shareByUid.forEach((uid, share) {
        if (uid == payer) return;
        final p = Money.toPaise(share);
        if (p == 0) return;
        if (payer == me) {
          paise[uid] = (paise[uid] ?? 0) + p; // they owe me
        } else if (uid == me) {
          paise[payer] = (paise[payer] ?? 0) - p; // I owe them
        }
      });
    }
    return {for (final e in paise.entries) e.key: Money.fromPaise(e.value)};
  }

  /// All non-zero pairwise debts in the group as directed transfers
  /// (who should pay whom), derived from direct shared expenses only.
  static List<Transfer> pairwiseDebts(Iterable<LedgerEntry> entries) {
    final owed = <String, int>{}; // "a|b" with a<b → paise b owes a (negative: a owes b)
    for (final e in entries) {
      if (e.isDeleted) continue;
      final payer = e.payerUid;
      e.shareByUid.forEach((uid, share) {
        if (uid == payer) return;
        final p = Money.toPaise(share);
        if (p == 0) return;
        // uid owes payer p
        final a = payer.compareTo(uid) < 0 ? payer : uid;
        final b = a == payer ? uid : payer;
        final key = '$a|$b';
        owed[key] = (owed[key] ?? 0) + (a == payer ? p : -p);
      });
    }
    final out = <Transfer>[];
    owed.forEach((key, v) {
      if (v == 0) return;
      final parts = key.split('|');
      // v > 0 → b owes a ; v < 0 → a owes b
      out.add(v > 0
          ? Transfer(parts[1], parts[0], Money.fromPaise(v))
          : Transfer(parts[0], parts[1], Money.fromPaise(-v)));
    });
    out.sort((x, y) => y.amount.compareTo(x.amount));
    return out;
  }
}

class _Bal {
  final String uid;
  int paise;
  _Bal(this.uid, this.paise);
}
