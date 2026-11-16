import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../export/export_service.dart';
import '../../home/domain/home_stats.dart';
import '../../personal_expenses/data/expense_repository.dart';

/// Personal export (CSV for spreadsheets, PDF for a readable report).
Future<void> showExportSheet(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const _ExportSheet());

enum _Preset { thisMonth, lastMonth, thisYear, all, custom }

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  _Preset _preset = _Preset.thisMonth;
  DateTimeRange? _custom;
  bool _busy = false;

  DateRange get _range {
    final now = DateTime.now();
    return switch (_preset) {
      _Preset.thisMonth => DateRange.month(now),
      _Preset.lastMonth => DateRange.month(DateTime(now.year, now.month - 1)),
      _Preset.thisYear => DateRange(RangeKind.custom, DateTime(now.year), DateTime(now.year + 1)),
      _Preset.all => DateRange(RangeKind.custom, DateTime(2000), DateTime(now.year + 1)),
      _Preset.custom => DateRange.of(RangeKind.custom, from: _custom?.start, to: _custom?.end),
    };
  }

  String get _label => switch (_preset) {
        _Preset.thisMonth || _Preset.lastMonth => Dates.monthYear(_range.start),
        _Preset.thisYear => '${DateTime.now().year}',
        _Preset.all => 'All time',
        _Preset.custom => _range.label,
      };

  Future<void> _export(bool pdf) async {
    final all = ref.read(personalExpensesProvider).valueOrNull ?? const [];
    final cats = ref.read(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final list = HomeStats.inRange(all, _range);
    if (list.isEmpty) {
      Toast.info('No expenses in $_label');
      return;
    }
    setState(() => _busy = true);
    try {
      final label = _label.replaceAll(' ', '_');
      if (pdf) {
        await ExportService.sharePersonalPdf(
          expenses: list,
          categories: cats,
          label: label,
          ownerName: ref.read(currentUserProfileProvider).valueOrNull?.displayName ?? 'Me',
        );
      } else {
        await ExportService.sharePersonalCsv(expenses: list, categories: cats, label: label);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Toast.error(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = HomeStats.inRange(ref.watch(personalExpensesProvider).valueOrNull ?? const [], _range).length;
    return SheetBody(
      title: 'Export my expenses',
      subtitle: 'Includes your personal expenses and your shares of group expenses.',
      children: [
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final (p, label) in [
              (_Preset.thisMonth, 'This month'),
              (_Preset.lastMonth, 'Last month'),
              (_Preset.thisYear, 'This year'),
              (_Preset.all, 'All time'),
            ])
              ChoiceChipX(label: label, selected: _preset == p, onTap: () => setState(() => _preset = p)),
            ChoiceChipX(
              label: _preset == _Preset.custom ? _range.label : 'Custom',
              icon: Icons.date_range_rounded,
              selected: _preset == _Preset.custom,
              onTap: () async {
                final now = DateTime.now();
                final r = await showDateRangePicker(context: context, firstDate: DateTime(2015), lastDate: now);
                if (r != null) {
                  setState(() {
                    _custom = r;
                    _preset = _Preset.custom;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text('$count expense${count == 1 ? '' : 's'} in $_label', style: context.text.bodyMedium?.copyWith(color: context.aurora.textMuted)),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(label: 'CSV', icon: Icons.table_chart_rounded, loading: _busy, onPressed: () => _export(false)),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: PrimaryButton(label: 'PDF report', icon: Icons.picture_as_pdf_rounded, loading: _busy, onPressed: () => _export(true)),
            ),
          ],
        ),
      ],
    );
  }
}
