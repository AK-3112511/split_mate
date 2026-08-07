import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconCode;
  final String colorHex;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorHex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'colorHex': colorHex,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      iconCode: map['iconCode'] ?? 'restaurant',
      colorHex: map['colorHex'] ?? 'C9A24B',
    );
  }

  // Helper static map of icons
  static const Map<String, IconData> iconMap = {
    'restaurant': Icons.restaurant,
    'home': Icons.home,
    'directions_car': Icons.directions_car,
    'movie': Icons.movie,
    'electrical_services': Icons.electrical_services,
    'shopping_bag': Icons.shopping_bag,
    'flight': Icons.flight,
    'work': Icons.work,
    'school': Icons.school,
    'health_and_safety': Icons.health_and_safety,
    'sports_esports': Icons.sports_esports,
    'miscellaneous_services': Icons.miscellaneous_services,
  };

  IconData get icon {
    return iconMap[iconCode] ?? Icons.category;
  }

  Color get color {
    String cleanHex = colorHex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    return Color(int.parse(cleanHex, radix: 16));
  }
}
