import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/domain/settlement.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/avatars.dart';
import '../../../../shared_widgets/buttons.dart';
import '../../../../shared_widgets/celebrate.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../../../shared_widgets/inputs.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../notifications/data/notifications_repository.dart';
import '../../data/group_expenses_repository.dart';
import '../../domain/group_expense_model.dart';
import '../../domain/group_model.dart';

/// Builds a UPI intent (NPCI deep-link spec). The app never moves money itself.
Uri upiUri({required String vpa, required String name, required double amount, required String note}) {
  return Uri(
    scheme: 'upi',
    host: 'pay',
    queryParameters: {
      'pa': vpa.trim(),
      'pn': name,
      'am': Money.round2(amount).toStringAsFixed(2),
      'cu': 'INR',
      'tn': note.length > 50 ? note.substring(0, 50) : note,
    },
  );
}

/// Record that [fromUid] paid [toUid]. Amount is editable (partial payments).
Future<void> showRecordPaymentSheet(
  BuildContext context, {
  required GroupModel group,
  required Transfer debt,
  required List<GroupExpenseModel> expenses,
}) {
  return showAppSheet<void>(context, builder: (_) => _RecordPayment(group: group, debt: debt, expenses: expenses));
}

class _RecordPayment extends ConsumerStatefulWidget {
  final GroupModel group;
  final Transfer debt;
  final List<GroupExpenseModel> expenses;
  const _RecordPayment({required this.group, required this.debt, required this.expenses});

  @override
  ConsumerState<_RecordPayment> createState() => _RecordPaymentState();
}

class _RecordPaymentState extends ConsumerState<_RecordPayment> {
  late final TextEditingController _amount = TextEditingController(text: Money.plain(widget.debt.amount));
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    final amount = Money.parse(_amount.text).value!;
    setState(() => _saving = true);
    final fromName = ref.read(realNameProvider(widget.debt.fromUid));
    final toName = ref.read(realNameProvider(widget.debt.toUid));
    try {
      final outcome = await ref.read(groupExpensesRepositoryProvider).recordPayment(
            group: widget.group,
            fromUid: widget.debt.fromUid,
            toUid: widget.debt.toUid,
            amount: amount,
            currentExpenses: widget.expenses,
            fromName: fromName,
            toName: toName,
          );
      if (!mounted) return;
      final cleared = Money.equals(amount, widget.debt.amount);
      // Confetti lives in the root overlay, so it outlives this sheet.
      if (cleared) Celebrate.show(context);
      Navigator.of(context).pop();
      if (cleared) {
        Toast.saved(outcome, 'All square with ${widget.debt.fromUid == ref.read(currentUidProvider) ? toName : fromName} 🎉');
      } else {
        Toast.saved(outcome, 'Payment of ${Money.format(amount)} recorded');
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final from = ref.watch(memberNameProvider(widget.debt.fromUid));
    final to = ref.watch(memberNameProvider(widget.debt.toUid));
    return SheetBody(
      title: 'Record a payment',
      subtitle: 'Only record money that has actually changed hands.',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(children: [UserAvatar(uid: widget.debt.fromUid, size: 56), const SizedBox(height: 6), Text(from, style: context.text.labelLarge)]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Icon(Icons.arrow_forward_rounded, color: c.primary, size: 28),
            ),
            Column(children: [UserAvatar(uid: widget.debt.toUid, size: 56), const SizedBox(height: 6), Text(to, style: context.text.labelLarge)]),
          ],
        ),
        const SizedBox(height: Space.md),
        Form(
          key: _form,
          child: MoneyField(
            controller: _amount,
            validator: (v) {
              final r = Money.parse(v);
              if (!r.isValid) return r.error;
              if (Money.toPaise(r.value!) > Money.toPaise(widget.debt.amount)) {
                return 'That\'s more than the ${Money.format(widget.debt.amount)} owed';
              }
              return null;
            },
          ),
        ),
        Center(
          child: Text('Owed: ${Money.format(widget.debt.amount)} · you can record part of it',
              style: context.text.bodySmall),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'Record payment', icon: Icons.check_rounded, loading: _saving, onPressed: _submit),
      ],
    );
  }
}

/// Opens the user's UPI app, then asks whether the payment went through.
Future<void> payViaUpi(
  BuildContext context,
  WidgetRef ref, {
  required GroupModel group,
  required Transfer debt,
  required List<GroupExpenseModel> expenses,
  required String vpa,
}) async {
  final toName = ref.read(realNameProvider(debt.toUid));
  final uri = upiUri(vpa: vpa, name: toName, amount: debt.amount, note: 'SplitMate · ${group.name}');
  bool launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!launched) {
    Toast.show('No UPI app found on this phone. Pay another way, then record it.', type: ToastType.info);
    return;
  }
  if (!context.mounted) return;
  final paid = await confirmAction(
    context,
    title: 'Did the payment go through?',
    message: 'If your UPI app showed success, record it so ${group.name} stays in sync.',
    confirmLabel: 'Yes, record it',
    icon: Icons.verified_rounded,
  );
  if (paid && context.mounted) {
    await showRecordPaymentSheet(context, group: group, debt: debt, expenses: expenses);
  }
}

/// Sends an in-app nudge (max once per 24h per person per group).
Future<void> sendReminder(WidgetRef ref, {required GroupModel group, required Transfer debt}) async {
  final repo = ref.read(notificationsRepositoryProvider);
  try {
    await repo.sendReminder(
      recipientUid: debt.fromUid,
      groupId: group.groupId,
      groupName: group.name,
      amount: debt.amount,
      message: '${repo.senderName} reminded you about ${Money.format(debt.amount)} in ${group.name}',
    );
    Toast.success('Reminder sent');
  } catch (e) {
    Toast.error(e);
  }
}
