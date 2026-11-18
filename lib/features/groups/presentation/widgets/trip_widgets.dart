import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/buttons.dart';
import '../../../../shared_widgets/cards.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../data/group_expenses_repository.dart';
import '../../data/groups_repository.dart';
import '../../domain/group_model.dart';
import '../../domain/trip_summary.dart';

/// "12–16 Dec · Day 3 of 5", "Starts 12 Dec", "Ended 16 Dec".
String tripStatus(GroupModel g, DateTime now) {
  if (!g.isTrip) return '';
  final range = TripSummary.dateRange(g.tripStart!, g.tripEnd!);
  final day = g.tripDay(now);
  if (day != null) return '$range · Day $day of ${g.tripDays}';
  if (g.tripOver(now)) return '$range · Trip over';
  return '$range · ${g.tripDays} ${g.tripDays == 1 ? 'day' : 'days'}';
}

/// Picks a currency from [Currencies.all]. Returns the code, or null if closed.
Future<String?> pickCurrency(BuildContext context, String current) {
  return showAppSheet<String>(
    context,
    builder: (ctx) => SheetBody(
      title: 'Currency',
      children: [
        for (final cur in Currencies.all)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: cur.code == current,
            leading: SizedBox(width: 48, child: Text(cur.symbol, style: ctx.text.titleMedium, maxLines: 1)),
            title: Text(cur.name),
            trailing: Text(cur.code, style: ctx.text.labelLarge),
            onTap: () => Navigator.of(ctx).pop(cur.code),
          ),
      ],
    ),
  );
}

/// Trip dates and currency, used when creating a group and in trip settings.
class TripFields extends StatelessWidget {
  final DateTimeRange? dates;
  final String currency;
  final ValueChanged<DateTimeRange> onDates;
  final ValueChanged<String> onCurrency;
  const TripFields({
    super.key,
    required this.dates,
    required this.currency,
    required this.onDates,
    required this.onCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final cur = Currencies.of(currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecondaryButton(
          label: dates == null ? 'Pick the trip dates' : TripSummary.dateRange(dates!.start, dates!.end),
          icon: Icons.date_range_rounded,
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 2),
              lastDate: DateTime(now.year + 2, 12, 31),
              initialDateRange: dates,
              helpText: 'Trip dates',
            );
            if (picked != null) onDates(picked);
          },
        ),
        const SizedBox(height: Space.sm),
        SecondaryButton(
          label: currency == Currencies.inr ? 'Spending in rupees' : 'Spending in ${cur.name} (${cur.code})',
          icon: Icons.currency_exchange_rounded,
          onPressed: () async {
            final code = await pickCurrency(context, currency);
            if (code != null) onCurrency(code);
          },
        ),
        const SizedBox(height: 4),
        Text(
          'New expenses start in this currency. Balances and settling stay in rupees.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

/// Admin: set, change or turn off trip mode.
Future<void> showTripSettingsSheet(BuildContext context, GroupModel group) {
  return showAppSheet<void>(context, builder: (_) => _TripSettings(group: group));
}

class _TripSettings extends ConsumerStatefulWidget {
  final GroupModel group;
  const _TripSettings({required this.group});

  @override
  ConsumerState<_TripSettings> createState() => _TripSettingsState();
}

class _TripSettingsState extends ConsumerState<_TripSettings> {
  late DateTimeRange? _dates = widget.group.isTrip
      ? DateTimeRange(start: widget.group.tripStart!, end: widget.group.tripEnd!)
      : null;
  late String _currency = widget.group.currency ?? Currencies.inr;
  bool _saving = false;

  Future<void> _save({bool off = false}) async {
    if (!off && _dates == null) {
      Toast.show('Pick the trip dates first', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(groupsRepositoryProvider)
          .setTrip(
            widget.group,
            start: off ? null : _dates!.start,
            end: off ? null : _dates!.end,
            currency: off ? null : _currency,
          );
      if (mounted) Navigator.of(context).pop();
      Toast.success(off ? 'Trip mode turned off' : 'Trip saved');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: widget.group.isTrip ? 'Trip dates & currency' : 'Make it a trip',
      subtitle: 'Shows the day of the trip, a summary at the end, and the fewest payments to settle everything.',
      children: [
        TripFields(
          dates: _dates,
          currency: _currency,
          onDates: (d) => setState(() => _dates = d),
          onCurrency: (c) => setState(() => _currency = c),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'Save trip', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
        if (widget.group.isTrip) ...[
          const SizedBox(height: Space.sm),
          SecondaryButton(
            label: 'Turn off trip mode',
            icon: Icons.luggage_outlined,
            onPressed: _saving ? null : () => _save(off: true),
          ),
        ],
      ],
    );
  }
}

/// Top of a trip's expense list: dates, day, spent so far, and the summary.
class TripCard extends ConsumerWidget {
  final GroupModel group;
  const TripCard({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final expenses = ref.watch(groupExpensesStreamProvider(group.groupId)).valueOrNull ?? const [];
    final summary = TripSummary.compute(group, expenses);
    final over = group.tripOver(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
      child: AppCard(
        color: over ? c.cta : null,
        onTap: () => context.push('/groups/${group.groupId}/trip'),
        child: Row(
          children: [
            Icon(over ? Icons.flag_rounded : Icons.luggage_rounded, size: 32, color: over ? c.onPop : c.text),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    over ? 'Trip\'s over. Time to settle up' : tripStatus(group, DateTime.now()),
                    style: context.text.titleSmall?.copyWith(color: over ? c.onPop : null),
                  ),
                  Text(
                    '${Money.format(summary.total)} spent · ${Money.format(summary.perDay)} a day',
                    style: context.text.bodySmall?.copyWith(color: over ? c.onPop : null),
                  ),
                ],
              ),
            ),
            Text('Summary', style: context.text.labelLarge?.copyWith(color: over ? c.onPop : c.primary)),
            Icon(Icons.chevron_right_rounded, color: over ? c.onPop : c.primary),
          ],
        ),
      ),
    );
  }
}
