import 'category_model.dart';

/// Single place that turns a stored category reference into a [CategoryModel].
///
/// v2 stores `categoryId`; v1 stored the category *name* (sometimes an id).
/// Group expenses store a name + icon/colour snapshot because every member has
/// their own personal category list.
class CategoryResolver {
  CategoryResolver._();

  static CategoryModel resolve({
    String? id,
    String? name,
    String? iconCode,
    String? colorHex,
    required List<CategoryModel> categories,
  }) {
    final cleanId = (id ?? '').trim();
    final cleanName = (name ?? '').trim();

    if (cleanId.isNotEmpty) {
      for (final c in categories) {
        if (c.id == cleanId) return c;
      }
      if (cleanId == CategoryModel.othersId) return CategoryModel.others;
    }

    final key = cleanName.isNotEmpty ? cleanName : cleanId;
    if (key.isEmpty) return CategoryModel.others;
    final lower = key.toLowerCase();

    for (final c in categories) {
      if (c.name.trim().toLowerCase() == lower || c.id.toLowerCase() == lower) return c;
    }
    for (final d in CategoryModel.defaults) {
      if (d.name.toLowerCase() == lower || d.id == lower) return d;
    }
    if (lower == 'other' || lower == 'others') return CategoryModel.others;

    // Unknown (e.g. a friend's custom group category): build a stable stand-in.
    final looksLikeUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-').hasMatch(lower);
    if (looksLikeUuid) return CategoryModel.others;
    return CategoryModel(
      id: 'name:$lower',
      name: _titleCase(key),
      iconCode: iconCode ?? guessIcon(key),
      colorHex: colorHex ?? _colorFor(lower),
    );
  }

  /// Totals per resolved category (canonical by id), largest first.
  static List<MapEntry<CategoryModel, double>> totals<T>({
    required Iterable<T> items,
    required CategoryModel Function(T) categoryOf,
    required double Function(T) amountOf,
  }) {
    final byId = <String, CategoryModel>{};
    final sums = <String, double>{};
    for (final item in items) {
      final c = categoryOf(item);
      byId[c.id] = c;
      sums[c.id] = (sums[c.id] ?? 0) + amountOf(item);
    }
    final list = [for (final e in sums.entries) MapEntry(byId[e.key]!, e.value)];
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  static String guessIcon(String name) {
    final l = name.toLowerCase();
    bool has(List<String> words) => words.any(l.contains);
    if (has(['food', 'dinner', 'lunch', 'eat', 'snack', 'pizza', 'restaurant'])) return 'restaurant';
    if (has(['coffee', 'cafe', 'tea'])) return 'local_cafe';
    if (has(['grocer', 'vegetable', 'fruit', 'milk'])) return 'local_grocery_store';
    if (has(['rent', 'home', 'house', 'room', 'flat'])) return 'home';
    if (has(['cab', 'car', 'auto', 'taxi', 'uber', 'ola', 'travel'])) return 'directions_car';
    if (has(['flight', 'trip', 'holiday'])) return 'flight';
    if (has(['train', 'metro', 'bus'])) return 'train';
    if (has(['fuel', 'petrol', 'diesel'])) return 'local_gas_station';
    if (has(['movie', 'film', 'party', 'fun', 'entertain'])) return 'movie';
    if (has(['game'])) return 'sports_esports';
    if (has(['bill', 'power', 'electric', 'water', 'utilit'])) return 'bolt';
    if (has(['wifi', 'internet', 'broadband'])) return 'wifi';
    if (has(['phone', 'mobile', 'recharge'])) return 'phone_iphone';
    if (has(['shop', 'cloth', 'amazon', 'buy'])) return 'shopping_bag';
    if (has(['health', 'med', 'doctor', 'pharma'])) return 'favorite';
    if (has(['gym', 'fitness', 'sport'])) return 'fitness_center';
    if (has(['school', 'book', 'course', 'college', 'fee'])) return 'school';
    if (has(['work', 'office'])) return 'work';
    if (has(['gift'])) return 'card_giftcard';
    if (has(['pet'])) return 'pets';
    return 'category';
  }

  static String _colorFor(String key) {
    final hash = key.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return CategoryModel.palette[hash % CategoryModel.palette.length];
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
