import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/image_codec.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/motion.dart';
import '../../../shared_widgets/receipt_viewer.dart';
import '../../../shared_widgets/states.dart';
import '../../groups/data/group_expenses_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../data/receipts_repository.dart';

class _ReceiptItem {
  final ReceiptRef ref;
  final String title;
  final String source;
  final double amount;
  final DateTime date;
  const _ReceiptItem(this.ref, this.title, this.source, this.amount, this.date);
}

/// All receipts across personal and group expenses. Images load lazily per tile.
class ReceiptsVaultScreen extends ConsumerStatefulWidget {
  const ReceiptsVaultScreen({super.key});

  @override
  ConsumerState<ReceiptsVaultScreen> createState() => _ReceiptsVaultScreenState();
}

class _ReceiptsVaultScreenState extends ConsumerState<ReceiptsVaultScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final personal = ref.watch(personalExpensesProvider);
    final groups = ref.watch(groupsStreamProvider).valueOrNull ?? const [];
    final items = <_ReceiptItem>[
      for (final e in personal.valueOrNull ?? const [])
        if (e.hasReceipt && !e.isMirror)
          _ReceiptItem(ReceiptRef(receiptId: e.receiptId, legacy: e.legacyReceipt), e.description, 'Personal', e.amount, e.date),
    ];
    var groupsLoading = false;
    for (final g in groups) {
      final ex = ref.watch(groupExpensesStreamProvider(g.groupId));
      if (ex.isLoading) groupsLoading = true;
      for (final e in ex.valueOrNull ?? const []) {
        if (!e.hasReceipt) continue;
        items.add(_ReceiptItem(
          ReceiptRef(groupId: g.groupId, receiptId: e.receiptId, legacy: e.legacyReceipt),
          e.description,
          g.name,
          e.amount,
          e.date,
        ));
      }
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    final q = _query.toLowerCase();
    final shown = q.isEmpty
        ? items
        : items.where((i) => i.title.toLowerCase().contains(q) || i.source.toLowerCase().contains(q)).toList();
    final loading = personal.isLoading || (items.isEmpty && groupsLoading);

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.popOrGo('/profile')), title: const Text('Receipts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(hintText: 'Search receipts', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          Expanded(
            child: loading
                ? const SkeletonList()
                : shown.isEmpty
                    ? Center(
                        child: EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: items.isEmpty ? 'No receipts yet' : 'No matches',
                          message: items.isEmpty ? 'Attach a photo when adding an expense and it\'ll be kept here.' : null,
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: Space.sm,
                          crossAxisSpacing: Space.sm,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: shown.length,
                        itemBuilder: (_, i) => _ReceiptTile(item: shown[i]).entrance(context, index: i),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptTile extends ConsumerWidget {
  final _ReceiptItem item;
  const _ReceiptTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final image = ref.watch(receiptImageProvider(item.ref));
    Widget thumb = Container(color: c.surfaceHigh);
    final data = image.valueOrNull;
    if (image.isLoading) {
      thumb = const Skeleton(child: SkeletonBox(height: double.infinity, borderRadius: BorderRadius.zero));
    } else if (ImageCodec.isDataUri(data)) {
      final bytes = ImageCodec.decode(data);
      if (bytes != null) thumb = Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 360, gaplessPlayback: true);
    } else if (ImageCodec.isNetwork(data)) {
      thumb = CachedNetworkImage(imageUrl: data!, fit: BoxFit.cover);
    } else {
      thumb = Center(child: Icon(Icons.broken_image_outlined, color: c.textMuted));
    }
    return Pressable(
      onTap: () => ReceiptViewer.show(context, receipt: item.ref, title: item.title),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.card,
          border: Border.all(color: c.outline),
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: thumb),
            Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.text.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${Money.format(item.amount)} · ${Dates.short(item.date)}', style: context.text.bodySmall, maxLines: 1),
                  Text(item.source, style: context.text.labelSmall?.copyWith(color: c.primary, letterSpacing: 0), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
