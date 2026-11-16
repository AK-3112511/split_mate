import 'package:characters/characters.dart';

/// Safe initials for avatars. Never throws (handles double spaces, emoji, empty).
String initialsOf(String? name, {String fallback = '?'}) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) {
    final chars = parts.first.characters;
    return (chars.length > 1 ? chars.take(2).toString() : chars.first).toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
}

/// First name only ("Arham Kansal" → "Arham").
String firstNameOf(String? name, {String fallback = 'there'}) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.isEmpty ? fallback : parts.first;
}
