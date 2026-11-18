import 'dart:convert';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/image_codec.dart';
import '../domain/bill_parser.dart';

/// A bill photo, what was read from it, and the photo itself to keep as the
/// receipt (null when it's too big to store).
class ScannedBill {
  final ParsedBill bill;
  final EncodedImage? receipt;
  final Uint8List? receiptBytes;
  const ScannedBill(this.bill, this.receipt, this.receiptBytes);
}

/// Takes / picks a photo and reads it with ML Kit's on-device text
/// recognition (no network, nothing leaves the phone).
class BillScanner {
  BillScanner._();

  static Future<ScannedBill?> scan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // Sharper than a normal receipt photo (small print), still storable.
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 75,
      requestFullMetadata: false,
    );
    if (picked == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(InputImage.fromFilePath(picked.path));
      final lines = [
        for (final block in text.blocks)
          for (final line in block.lines)
            OcrLine(
              line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
              angle: line.angle ?? 0,
            ),
      ];
      final bill = BillParser.parse(lines);

      final bytes = await picked.readAsBytes();
      final encoded = base64Encode(bytes);
      final fits = encoded.length <= ImageCodec.maxReceiptBase64;
      final mime = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      return ScannedBill(bill, fits ? EncodedImage(encoded, mime) : null, fits ? bytes : null);
    } finally {
      await recognizer.close();
    }
  }
}
