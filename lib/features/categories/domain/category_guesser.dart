import 'category_model.dart';

/// One past expense the guesser learns from.
class CategoryHint {
  final String description;
  final String categoryId;
  final double amount;
  final DateTime date;

  /// False for your share of a group expense: it still teaches the guesser,
  /// but isn't offered as a one-tap personal quick pick.
  final bool personal;
  const CategoryHint({
    required this.description,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.personal = true,
  });
}

enum GuessSource { history, categoryName, keyword }

class CategoryGuess {
  final CategoryModel category;
  final GuessSource source;
  const CategoryGuess(this.category, this.source);
}

/// Something you add often: one tap fills the description and category, and
/// the amount when it has always been the same.
class QuickPick {
  final String description;
  final CategoryModel category;
  final double? amount;
  const QuickPick({required this.description, required this.category, this.amount});
}

/// Picks a category from what you type: first from your own history ("Chai"
/// was Food last time), then from a category name in the text, then from a
/// built-in list of common Indian merchants and words ("Uber" → Travel).
///
/// Pure and synchronous; build one per screen from the current history.
class CategoryGuesser {
  final List<CategoryModel> categories;
  final Map<String, CategoryModel> _byId;

  /// normalised description → category id → count.
  final Map<String, Map<String, int>> _exact = {};

  /// token → category id → count.
  final Map<String, Map<String, int>> _tokens = {};

  final List<CategoryHint> _history;

  CategoryGuesser({required this.categories, required Iterable<CategoryHint> history})
    : _byId = {for (final c in categories) c.id: c},
      _history = (history.toList()..sort((a, b) => b.date.compareTo(a.date))) {
    // Newest first, so map insertion order doubles as recency (ties → newest).
    for (final h in _history) {
      if (!_byId.containsKey(h.categoryId)) continue;
      final n = normalize(h.description);
      if (n.isEmpty) continue;
      final exact = _exact.putIfAbsent(n, () => {});
      exact[h.categoryId] = (exact[h.categoryId] ?? 0) + 1;
      for (final t in tokensOf(n).toSet()) {
        final m = _tokens.putIfAbsent(t, () => {});
        m[h.categoryId] = (m[h.categoryId] ?? 0) + 1;
      }
    }
  }

  CategoryGuess? guess(String description) {
    final n = normalize(description);
    if (n.length < 2) return null;
    final padded = ' $n ';

    // 1. You've typed exactly this before.
    final exact = _exact[n];
    if (exact != null) return CategoryGuess(_best(exact), GuessSource.history);

    // 2. A category's own name is in the text ("Rent for May", "Coffee at CCD").
    CategoryModel? named;
    for (final c in categories) {
      final name = normalize(c.name);
      if (name.length < 3 || c.id == CategoryModel.othersId) continue;
      if (padded.contains(' $name ') && (named == null || name.length > normalize(named.name).length)) {
        named = c;
      }
    }
    if (named != null) return CategoryGuess(named, GuessSource.categoryName);

    // 3. A word you've used at least twice, always (or nearly) for one category.
    final scores = <String, double>{};
    for (final t in tokensOf(n).toSet()) {
      final m = _tokens[t];
      if (m == null) continue;
      final total = m.values.fold<int>(0, (a, b) => a + b);
      if (total < 2) continue;
      final top = m.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final consistency = top.value / total;
      if (consistency < 0.7) continue;
      scores[top.key] = (scores[top.key] ?? 0) + consistency * (total.clamp(2, 5) / 5);
    }
    if (scores.isNotEmpty) {
      final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return CategoryGuess(_byId[best.key]!, GuessSource.history);
    }

    // 4. Built-in words: phrases first, so "uber eats" beats "uber".
    for (final kind in _phrases.entries) {
      for (final p in kind.value) {
        if (padded.contains(' $p ')) {
          final c = _resolveKind(kind.key);
          if (c != null) return CategoryGuess(c, GuessSource.keyword);
        }
      }
    }
    for (final t in tokensOf(n)) {
      final kind = _wordKinds[t];
      if (kind == null) continue;
      final c = _resolveKind(kind);
      if (c != null) return CategoryGuess(c, GuessSource.keyword);
    }
    return null;
  }

  /// Your most frequent recent descriptions, for one-tap adding.
  List<QuickPick> quickPicks({int limit = 6, DateTime? now, int days = 90}) {
    final since = (now ?? DateTime.now()).subtract(Duration(days: days));
    final groups = <String, List<CategoryHint>>{};
    final display = <String, String>{};
    for (final h in _history) {
      if (!h.personal || h.date.isBefore(since) || !_byId.containsKey(h.categoryId)) continue;
      final n = normalize(h.description);
      if (n.isEmpty) continue;
      groups.putIfAbsent(n, () => []).add(h);
      display.putIfAbsent(n, () => h.description.trim());
    }
    final ranked = groups.entries.where((e) => e.value.length >= 2).toList()
      ..sort((a, b) {
        final byCount = b.value.length.compareTo(a.value.length);
        return byCount != 0 ? byCount : b.value.first.date.compareTo(a.value.first.date);
      });
    return [
      for (final e in ranked.take(limit))
        QuickPick(
          description: display[e.key]!,
          category: _best({
            for (final h in e.value) h.categoryId: e.value.where((x) => x.categoryId == h.categoryId).length,
          }),
          amount: _steadyAmount(e.value),
        ),
    ];
  }

  /// The amount, if the last few times (at least two) were all the same.
  static double? _steadyAmount(List<CategoryHint> newestFirst) {
    final recent = newestFirst.take(3).map((h) => (h.amount * 100).round()).toSet();
    return recent.length == 1 ? newestFirst.first.amount : null;
  }

  /// Most used; on a tie the one used most recently (maps are filled newest first).
  CategoryModel _best(Map<String, int> counts) {
    var best = counts.entries.first;
    for (final e in counts.entries) {
      if (e.value > best.value) best = e;
    }
    return _byId[best.key]!;
  }

  CategoryModel? _resolveKind(String kind) {
    final byId = _byId[kind];
    if (byId != null) return byId;
    final names = _kindNames[kind] ?? const <String>[];
    for (final c in categories) {
      if (names.contains(normalize(c.name))) return c;
    }
    return null;
  }

  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r"['’.]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static const _stop = {
    'the',
    'and',
    'for',
    'with',
    'from',
    'at',
    'to',
    'of',
    'in',
    'on',
    'my',
    'our',
    'bill',
    'paid',
    'pay',
    'payment',
    'order',
    'today',
    'yesterday',
    'some',
    'got',
    'bought',
    'share',
    'split',
  };

  static Iterable<String> tokensOf(String normalized) =>
      normalized.split(' ').where((t) => t.length >= 2 && !_stop.contains(t) && !RegExp(r'^\d+$').hasMatch(t));

  /// Names a user may have given the default categories.
  static const Map<String, List<String>> _kindNames = {
    'food': ['food', 'dining', 'eating out', 'restaurants', 'meals', 'food and drinks'],
    'groceries': ['groceries', 'grocery', 'household', 'kirana'],
    'rent': ['rent', 'housing', 'home', 'house'],
    'travel': ['travel', 'transport', 'transportation', 'commute', 'cab', 'cabs', 'fuel'],
    'shopping': ['shopping', 'clothes'],
    'entertainment': ['entertainment', 'fun', 'movies', 'subscriptions', 'leisure'],
    'utilities': ['utilities', 'bills', 'utility'],
    'health': ['health', 'medical', 'fitness', 'medicine', 'healthcare'],
  };

  static const Map<String, List<String>> _phrases = {
    'food': ['uber eats', 'ice cream', 'eat sure', 'zepto cafe', 'pani puri', 'swiggy dineout'],
    'groceries': [
      'big basket',
      'reliance fresh',
      'natures basket',
      'more supermarket',
      'jio mart',
      'd mart',
      'big bazaar',
      'swiggy instamart',
    ],
    'rent': ['house rent', 'room rent', 'flat rent', 'pg rent'],
    'travel': ['air india', 'red bus', 'auto rickshaw', 'make my trip', 'quick ride'],
    'shopping': ['tata cliq', 'reliance digital'],
    'entertainment': [
      'amazon prime',
      'prime video',
      'youtube premium',
      'apple music',
      'book my show',
      'disney hotstar',
    ],
    'utilities': [
      'electricity bill',
      'power bill',
      'water bill',
      'gas bill',
      'mobile recharge',
      'phone bill',
      'tata play',
      'act fibernet',
      'wi fi',
    ],
    'health': ['blood test', 'cult fit'],
  };

  static final Map<String, String> _wordKinds = {
    for (final w in const [
      'swiggy',
      'zomato',
      'dominos',
      'domino',
      'pizza',
      'burger',
      'mcdonalds',
      'mcd',
      'kfc',
      'subway',
      'starbucks',
      'chai',
      'tea',
      'coffee',
      'cafe',
      'ccd',
      'barista',
      'dinner',
      'lunch',
      'breakfast',
      'brunch',
      'snacks',
      'snack',
      'biryani',
      'restaurant',
      'dhaba',
      'canteen',
      'mess',
      'maggi',
      'momos',
      'momo',
      'juice',
      'icecream',
      'bakery',
      'cake',
      'sweets',
      'mithai',
      'haldiram',
      'haldirams',
      'eatsure',
      'food',
      'meal',
      'thali',
      'dosa',
      'paratha',
      'samosa',
      'chaayos',
      'shawarma',
      'rolls',
      'chaat',
      'tiffin',
    ])
      w: 'food',
    for (final w in const [
      'blinkit',
      'zepto',
      'instamart',
      'bigbasket',
      'dmart',
      'jiomart',
      'grofers',
      'grocery',
      'groceries',
      'vegetables',
      'veggies',
      'sabzi',
      'sabji',
      'fruits',
      'milk',
      'doodh',
      'eggs',
      'bread',
      'kirana',
      'ration',
      'spencers',
      'supermarket',
      'dunzo',
      'atta',
    ])
      w: 'groceries',
    for (final w in const ['rent', 'pg', 'hostel', 'landlord', 'brokerage', 'deposit']) w: 'rent',
    for (final w in const [
      'uber',
      'ola',
      'rapido',
      'auto',
      'cab',
      'taxi',
      'metro',
      'bus',
      'train',
      'irctc',
      'flight',
      'flights',
      'indigo',
      'vistara',
      'akasa',
      'spicejet',
      'makemytrip',
      'mmt',
      'goibibo',
      'redbus',
      'petrol',
      'diesel',
      'fuel',
      'cng',
      'toll',
      'fastag',
      'parking',
      'yulu',
      'bounce',
      'blablacar',
      'ixigo',
      'cleartrip',
      'airport',
      'travel',
      'trip',
      'hotel',
      'oyo',
      'airbnb',
      'commute',
    ])
      w: 'travel',
    for (final w in const [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'meesho',
      'nykaa',
      'decathlon',
      'zara',
      'uniqlo',
      'westside',
      'pantaloons',
      'ikea',
      'croma',
      'clothes',
      'shoes',
      'shirt',
      'tshirt',
      'jeans',
      'dress',
      'kurta',
      'saree',
      'shopping',
      'headphones',
      'earphones',
      'charger',
      'gift',
      'gifts',
    ])
      w: 'shopping',
    for (final w in const [
      'netflix',
      'prime',
      'hotstar',
      'jiocinema',
      'sonyliv',
      'zee5',
      'spotify',
      'gaana',
      'movie',
      'movies',
      'cinema',
      'pvr',
      'inox',
      'cinepolis',
      'bookmyshow',
      'bms',
      'concert',
      'party',
      'club',
      'bowling',
      'gaming',
      'game',
      'games',
      'steam',
      'playstation',
      'ps5',
      'xbox',
      'bgmi',
      'outing',
      'beer',
      'drinks',
      'bar',
      'pub',
      'theatre',
      'standup',
      'comedy',
      'event',
      'tickets',
    ])
      w: 'entertainment',
    for (final w in const [
      'electricity',
      'bijli',
      'electric',
      'wifi',
      'broadband',
      'internet',
      'jio',
      'airtel',
      'vodafone',
      'bsnl',
      'recharge',
      'dth',
      'tatasky',
      'cylinder',
      'lpg',
      'indane',
      'gas',
      'maintenance',
      'laundry',
      'dhobi',
      'utilities',
      'postpaid',
      'prepaid',
    ])
      w: 'utilities',
    for (final w in const [
      'medicine',
      'medicines',
      'meds',
      'pharmacy',
      'chemist',
      'apollo',
      '1mg',
      'pharmeasy',
      'netmeds',
      'doctor',
      'dr',
      'clinic',
      'hospital',
      'dentist',
      'lab',
      'checkup',
      'gym',
      'cultfit',
      'yoga',
      'physio',
      'practo',
      'tablets',
      'health',
    ])
      w: 'health',
  };
}
