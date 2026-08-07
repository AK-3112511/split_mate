class AppConstants {
  static const String appName = 'SplitTrack';
  
  // Default category list seeded for new users
  static const List<Map<String, dynamic>> defaultCategories = [
    {'name': 'Food', 'iconCode': 'restaurant', 'colorHex': 'FF5722'},
    {'name': 'Rent', 'iconCode': 'home', 'colorHex': '2196F3'},
    {'name': 'Travel', 'iconCode': 'directions_car', 'colorHex': '4CAF50'},
    {'name': 'Entertainment', 'iconCode': 'movie', 'colorHex': '9C27B0'},
    {'name': 'Utilities', 'iconCode': 'electrical_services', 'colorHex': 'FFEB3B'},
  ];
}
