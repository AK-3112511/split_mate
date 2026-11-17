import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/domain/settlement.dart';
import '../../../../core/legal.dart';
import '../../../../core/share_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/buttons.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../friends/data/friends_repository.dart';
import '../../domain/group_expense_model.dart';
import '../../domain/group_model.dart';
import '../../domain/guest.dart';

// ── Balance summary image ────────────────────────────────────────────────────

/// Preview + share of the group's balances as an image for the group chat.
Future<void> showShareBalancesSheet(
  BuildContext context, {
  required GroupModel group,
  required List<Transfer> debts,
  required bool simplified,
  required List<GroupExpenseModel> expenses,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => _ShareBalancesSheet(group: group, debts: debts, simplified: simplified, expenses: expenses),
  );
}

class _ShareBalancesSheet extends ConsumerStatefulWidget {
  final GroupModel group;
  final List<Transfer> debts;
  final bool simplified;
  final List<GroupExpenseModel> expenses;
  const _ShareBalancesSheet({required this.group, required this.debts, required this.simplified, required this.expenses});

  @override
  ConsumerState<_ShareBalancesSheet> createState() => _ShareBalancesSheetState();
}

class _ShareBalancesSheetState extends ConsumerState<_ShareBalancesSheet> {
  final _key = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/splitmate_${widget.group.groupId}_balances.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      final code = widget.group.inviteCode;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Balances for "${widget.group.name}" on SplitMate.'
            '${code == null ? '' : ' Join the group: ${groupInviteLink(code)}'}',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spent = widget.expenses
        .where((e) => !e.isPayment && !e.isDeleted)
        .fold<int>(0, (sum, e) => sum + Money.toPaise(e.amount));
    return SheetBody(
      title: 'Share balances',
      subtitle: 'Send this to your group chat so everyone knows where things stand.',
      children: [
        Center(
          child: RepaintBoundary(
            key: _key,
            child: _BalanceCard(
              groupName: widget.group.name,
              spent: Money.fromPaise(spent),
              simplified: widget.simplified,
              lines: [
                for (final d in widget.debts)
                  (from: ref.watch(realNameProvider(d.fromUid)), to: ref.watch(realNameProvider(d.toUid)), amount: d.amount),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        PrimaryButton(label: 'Share', icon: Icons.ios_share_rounded, loading: _sharing, onPressed: _share),
      ],
    );
  }
}

/// Fixed light "sticker" look so the image reads the same in every chat.
class _BalanceCard extends StatelessWidget {
  final String groupName;
  final double spent;
  final bool simplified;
  final List<({String from, String to, double amount})> lines;
  const _BalanceCard({required this.groupName, required this.spent, required this.simplified, required this.lines});

  @override
  Widget build(BuildContext context) {
    const ink = Palette.ink;
    final text = context.text;
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Palette.paper,
        borderRadius: Radii.hero,
        border: Border.all(color: ink, width: Brutal.border),
        boxShadow: const [BoxShadow(color: ink, offset: Offset(6, 6))],
      ),
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(groupName, style: text.titleLarge?.copyWith(color: ink), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            '${Dates.short(DateTime.now())} · ${Money.format(spent)} spent',
            style: text.bodySmall?.copyWith(color: ink),
          ),
          const SizedBox(height: Space.md),
          Text(
            lines.isEmpty ? 'All settled up 🎉' : (simplified ? 'To settle up' : 'Who owes whom'),
            style: text.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Space.xs),
          for (final l in lines)
            Container(
              margin: const EdgeInsets.only(bottom: Space.xs),
              padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
              decoration: BoxDecoration(
                color: Palette.yellow,
                borderRadius: Radii.chip,
                border: Border.all(color: ink, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${l.from} → ${l.to}',
                        style: text.bodyMedium?.copyWith(color: ink, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: Space.sm),
                  Text(Money.format(l.amount),
                      style: text.bodyMedium?.copyWith(color: ink, fontWeight: FontWeight.w800, fontFeatures: AppTheme.tabular)),
                ],
              ),
            ),
          const SizedBox(height: Space.sm),
          Text('Split with SplitMate', style: text.labelSmall?.copyWith(color: ink)),
        ],
      ),
    );
  }
}

// ── WhatsApp reminder ────────────────────────────────────────────────────────

/// Opens WhatsApp with a ready "you owe me" message (pay link if I have a UPI
/// ID; claim link if they aren't on SplitMate yet). Falls back to the share
/// sheet when WhatsApp isn't installed.
Future<void> remindOnWhatsApp(WidgetRef ref, {required GroupModel group, required Transfer debt}) async {
  final me = ref.read(currentUserProfileProvider).valueOrNull;
  final myUpi = me?.upiId;
  final hasUpi = myUpi != null && myUpi.trim().isNotEmpty;
  final guest = group.guests[debt.fromUid];
  final code = group.inviteCode;

  final message = paymentReminderText(
    debtorName: ref.read(realNameProvider(debt.fromUid)),
    groupName: group.name,
    amount: debt.amount,
    payLink: hasUpi
        ? upiPayPageLink(vpa: myUpi, name: me?.displayName ?? 'SplitMate', amount: debt.amount, note: 'SplitMate · ${group.name}')
        : null,
    claimLink: isGuestId(debt.fromUid) && guest != null && code != null ? guestClaimLink(code, guest.id) : null,
  );

  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
  if (!opened) await Share.share(message);
  if (!hasUpi) {
    Toast.show('Tip: add your UPI ID in Profile → Personal info so reminders include a pay link.', type: ToastType.info);
  }
}
