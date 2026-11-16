import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../core/utils/image_codec.dart';
import '../features/receipts/data/receipts_repository.dart';
import 'states.dart';

/// Full-screen, pinch-to-zoom receipt viewer. Loads the image on demand.
class ReceiptViewer extends ConsumerWidget {
  final ReceiptRef receipt;
  final String title;
  const ReceiptViewer({super.key, required this.receipt, required this.title});

  static Future<void> show(BuildContext context, {required ReceiptRef receipt, required String title}) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => ReceiptViewer(receipt: receipt, title: title),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(receiptImageProvider(receipt));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(color: Colors.white)),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: image.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => Center(child: ErrorState(error: e, onRetry: () => ref.invalidate(receiptImageProvider(receipt)))),
          data: (data) {
            Widget? img;
            final bytes = ImageCodec.isDataUri(data) ? ImageCodec.decode(data) : null;
            if (bytes != null) {
              img = Image.memory(bytes, fit: BoxFit.contain);
            } else if (ImageCodec.isNetwork(data)) {
              img = CachedNetworkImage(imageUrl: data!, fit: BoxFit.contain);
            }
            if (img == null) {
              return Center(
                child: Text('This receipt couldn\'t be opened.',
                    style: context.text.bodyLarge?.copyWith(color: Colors.white70)),
              );
            }
            return InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Padding(padding: const EdgeInsets.all(Space.md), child: img),
              ),
            );
          },
        ),
      ),
    );
  }
}
