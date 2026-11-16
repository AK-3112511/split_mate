import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/image_codec.dart';
import '../../auth/data/auth_repository.dart';

/// Points at a receipt image wherever it lives.
class ReceiptRef {
  /// Group receipts live under the group; personal ones under the user.
  final String? groupId;
  final String? receiptId;

  /// v1 stored the image inline on the expense (data URI or URL).
  final String? legacy;

  const ReceiptRef({this.groupId, this.receiptId, this.legacy});

  bool get isEmpty => receiptId == null && (legacy == null || legacy!.isEmpty);

  @override
  bool operator ==(Object other) =>
      other is ReceiptRef &&
      other.groupId == groupId &&
      other.receiptId == receiptId &&
      other.legacy == legacy;

  @override
  int get hashCode => Object.hash(groupId, receiptId, legacy?.length);
}

final receiptsRepositoryProvider = Provider<ReceiptsRepository>((ref) {
  return ReceiptsRepository(ref.watch(firestoreProvider), ref.watch(currentUidProvider));
});

/// Loads a receipt image (data URI / URL) on demand — never as part of a list.
final receiptImageProvider = FutureProvider.autoDispose.family<String?, ReceiptRef>((ref, r) async {
  if (r.receiptId == null) return r.legacy;
  return ref.watch(receiptsRepositoryProvider).load(r);
});

class ReceiptsRepository {
  final FirebaseFirestore _db;
  final String? _uid;

  ReceiptsRepository(this._db, this._uid);

  CollectionReference<Map<String, dynamic>> collection({String? groupId}) {
    if (groupId != null) return _db.collection('groups').doc(groupId).collection('receipts');
    return _db.collection('users').doc(_uid).collection('receipts');
  }

  /// Adds the receipt write to [batch] and returns its id.
  String stage(WriteBatch batch, EncodedImage image, {String? groupId, String? expenseId}) {
    final doc = collection(groupId: groupId).doc();
    batch.set(doc, {
      'data': image.dataUri,
      'mimeType': image.mimeType,
      'expenseId': expenseId,
      'uploadedBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<String?> load(ReceiptRef r) async {
    if (r.receiptId == null) return r.legacy;
    final snap = await collection(groupId: r.groupId).doc(r.receiptId).get();
    return snap.data()?['data'] as String?;
  }

  Future<void> delete(String receiptId, {String? groupId}) async {
    await collection(groupId: groupId).doc(receiptId).delete();
  }
}
