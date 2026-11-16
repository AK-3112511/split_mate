import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'app_exception.dart';

/// A picked image already compressed and base64-encoded for Firestore storage
/// (Spark plan: no Cloud Storage). Stored in its own document, never in lists.
class EncodedImage {
  final String base64;
  final String mimeType;
  const EncodedImage(this.base64, this.mimeType);

  String get dataUri => 'data:$mimeType;base64,$base64';
  int get sizeBytes => base64.length;
}

class ImageCodec {
  ImageCodec._();

  /// Firestore docs max out at 1 MiB; leave headroom for other fields.
  static const int maxReceiptBase64 = 900 * 1024;
  static const int maxAvatarBase64 = 150 * 1024;

  static Future<EncodedImage?> pick({
    required ImageSource source,
    double maxDimension = 1280,
    int quality = 60,
    int maxBase64Bytes = maxReceiptBase64,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: quality,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final encoded = base64Encode(bytes);
    if (encoded.length > maxBase64Bytes) {
      throw const AppException('That image is too large. Try a closer, simpler photo.');
    }
    final lower = picked.name.toLowerCase();
    final mime = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    return EncodedImage(encoded, mime);
  }

  /// Avatar preset: small square-ish image that fits in the public profile doc.
  static Future<EncodedImage?> pickAvatar(ImageSource source) => pick(
        source: source,
        maxDimension: 320,
        quality: 70,
        maxBase64Bytes: maxAvatarBase64,
      );

  /// Decodes "data:…;base64,XXXX" or raw base64. Returns null when invalid.
  static Uint8List? decode(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      final comma = data.indexOf(',');
      final raw = data.startsWith('data:') && comma != -1 ? data.substring(comma + 1) : data;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  static bool isDataUri(String? s) => s != null && s.startsWith('data:image');
  static bool isNetwork(String? s) =>
      s != null && (s.startsWith('http://') || s.startsWith('https://'));
}
