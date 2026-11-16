import '../../categories/domain/category_model.dart';
import '../../personal_expenses/domain/expense_model.dart' show readDate;
import '../../../core/utils/image_codec.dart';

/// Public profile at users/{uid}. Readable by any signed-in user, so it holds
/// nothing private (email lives in users/{uid}/private/profile).
class UserProfile {
  final String uid;
  final String displayName;

  /// Small base64 avatar (v2). Visible to friends.
  final String? photoData;

  /// External photo URL (e.g. Google account photo). v1 local paths are ignored.
  final String? photoUrl;
  final String? appCode;
  final String? upiId;
  final List<CategoryModel> categories;
  final DateTime? createdAt;
  final DateTime? mirrorScanAt;

  /// True when the v1 doc still has `email` in the public doc (migrate it).
  final bool hasLegacyEmail;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.photoData,
    this.photoUrl,
    this.appCode,
    this.upiId,
    this.categories = const [],
    this.createdAt,
    this.mirrorScanAt,
    this.hasLegacyEmail = false,
  });

  /// Best avatar source: inline data first, then a real network URL.
  String? get avatar {
    if (photoData != null && photoData!.isNotEmpty) return photoData;
    if (ImageCodec.isNetwork(photoUrl)) return photoUrl;
    return null;
  }

  bool get hasUpi => upiId != null && upiId!.trim().isNotEmpty;

  factory UserProfile.fromMap(String uid, Map<String, dynamic>? map) {
    final m = map ?? const {};
    final rawCats = m['categories'];
    final cats = rawCats is List
        ? rawCats
            .whereType<Map>()
            .map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e)))
            .where((c) => c.id.isNotEmpty)
            .toList()
        : <CategoryModel>[];
    final name = (m['displayName'] ?? '').toString().trim();
    return UserProfile(
      uid: uid,
      displayName: name.isEmpty ? 'SplitMate user' : name,
      photoData: m['photoData'] as String?,
      photoUrl: m['photoUrl'] as String?,
      appCode: (m['appCode'] as String?)?.toUpperCase(),
      upiId: m['upiId'] as String?,
      categories: cats,
      createdAt: readDate(m['createdAt']),
      mirrorScanAt: readDate(m['mirrorScanAt']),
      hasLegacyEmail: m.containsKey('email'),
    );
  }
}
