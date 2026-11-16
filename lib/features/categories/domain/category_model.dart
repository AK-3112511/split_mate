import 'package:material_ui/material_ui.dart';

/// A spending category. Personal categories live on the user's profile doc.
class CategoryModel {
  final String id;
  final String name;
  final String iconCode;
  final String colorHex;

  /// Optional monthly budget in ₹ (null = no budget).
  final double? monthlyBudget;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorHex,
    this.monthlyBudget,
  });

  static const String othersId = 'others';

  static const CategoryModel others = CategoryModel(
    id: othersId,
    name: 'Other',
    iconCode: 'category',
    colorHex: '64748B',
  );

  /// Seeded for every new user. Ids of the first five match v1 seeds.
  static const List<CategoryModel> defaults = [
    CategoryModel(id: 'food', name: 'Food', iconCode: 'restaurant', colorHex: 'F97316'),
    CategoryModel(id: 'groceries', name: 'Groceries', iconCode: 'local_grocery_store', colorHex: '22C55E'),
    CategoryModel(id: 'rent', name: 'Rent', iconCode: 'home', colorHex: '3B82F6'),
    CategoryModel(id: 'travel', name: 'Travel', iconCode: 'directions_car', colorHex: '06B6D4'),
    CategoryModel(id: 'shopping', name: 'Shopping', iconCode: 'shopping_bag', colorHex: 'EC4899'),
    CategoryModel(id: 'entertainment', name: 'Entertainment', iconCode: 'movie', colorHex: 'D946EF'),
    CategoryModel(id: 'utilities', name: 'Utilities', iconCode: 'bolt', colorHex: 'F59E0B'),
    CategoryModel(id: 'health', name: 'Health', iconCode: 'favorite', colorHex: 'EF4444'),
  ];

  /// The 12 vivid category hues (see DESIGN_SYSTEM.md).
  static const List<String> palette = [
    '8B5CF6', '3B82F6', '06B6D4', '14B8A6', '22C55E', '84CC16',
    'F59E0B', 'F97316', 'EF4444', 'EC4899', 'D946EF', '64748B',
  ];

  /// v1 seeded harsh Material colours / muted gold — mapped to the new palette.
  static const Map<String, String> legacyColorMap = {
    'FF5722': 'F97316',
    '2196F3': '3B82F6',
    '4CAF50': '14B8A6',
    '9C27B0': 'D946EF',
    'FFEB3B': 'F59E0B',
    'C9A24B': 'F59E0B',
    'D4AF37': 'F59E0B',
    '9E9E9E': '64748B',
  };

  static const Map<String, IconData> iconMap = {
    'restaurant': Icons.restaurant_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'local_grocery_store': Icons.local_grocery_store_rounded,
    'home': Icons.home_rounded,
    'directions_car': Icons.directions_car_rounded,
    'flight': Icons.flight_rounded,
    'train': Icons.train_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'movie': Icons.movie_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'music_note': Icons.music_note_rounded,
    'bolt': Icons.bolt_rounded,
    'electrical_services': Icons.bolt_rounded,
    'wifi': Icons.wifi_rounded,
    'phone_iphone': Icons.phone_iphone_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'checkroom': Icons.checkroom_rounded,
    'favorite': Icons.favorite_rounded,
    'health_and_safety': Icons.health_and_safety_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'school': Icons.school_rounded,
    'work': Icons.work_rounded,
    'pets': Icons.pets_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'celebration': Icons.celebration_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'savings': Icons.savings_rounded,
    'miscellaneous_services': Icons.category_rounded,
    'category': Icons.category_rounded,
  };

  /// Icons offered in the category editor (unique visuals only).
  static const List<String> pickableIcons = [
    'restaurant', 'local_cafe', 'local_grocery_store', 'home', 'directions_car', 'flight',
    'train', 'local_gas_station', 'movie', 'sports_esports', 'music_note', 'bolt',
    'wifi', 'phone_iphone', 'shopping_bag', 'checkroom', 'favorite', 'fitness_center',
    'school', 'work', 'pets', 'card_giftcard', 'celebration', 'savings',
  ];

  IconData get icon => iconMap[iconCode] ?? Icons.category_rounded;

  Color get color => colorFromHex(colorHex);

  static Color colorFromHex(String hex) {
    var clean = hex.replaceAll('#', '').toUpperCase();
    clean = legacyColorMap[clean] ?? clean;
    if (clean.length == 6) clean = 'FF$clean';
    final value = int.tryParse(clean, radix: 16);
    return Color(value ?? 0xFF64748B);
  }

  bool get hasBudget => monthlyBudget != null && monthlyBudget! > 0;

  CategoryModel copyWith({
    String? name,
    String? iconCode,
    String? colorHex,
    double? monthlyBudget,
    bool clearBudget = false,
  }) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorHex: colorHex ?? this.colorHex,
      monthlyBudget: clearBudget ? null : (monthlyBudget ?? this.monthlyBudget),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconCode': iconCode,
        'colorHex': colorHex,
        if (monthlyBudget != null) 'monthlyBudget': monthlyBudget,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    final rawHex = (map['colorHex'] ?? '64748B').toString().replaceAll('#', '').toUpperCase();
    final budget = map['monthlyBudget'];
    return CategoryModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      iconCode: (map['iconCode'] ?? 'category').toString(),
      colorHex: legacyColorMap[rawHex] ?? rawHex,
      monthlyBudget: budget is num && budget > 0 ? budget.toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) => other is CategoryModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
