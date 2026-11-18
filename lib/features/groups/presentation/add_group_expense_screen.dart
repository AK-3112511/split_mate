import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/domain/recurrence.dart';
import '../../../core/domain/split_calculator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/image_codec.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/recurring_engine.dart';
import '../../../core/utils/write_helper.dart';
import '../../../shared_widgets/avatars.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../../../shared_widgets/states.dart';
import '../../auth/data/auth_repository.dart';
import '../../bill_scan/data/bill_scanner.dart';
import '../../bill_scan/domain/bill_parser.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/data/category_guesser_provider.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/domain/category_resolver.dart';
import '../../friends/data/friends_repository.dart';
import '../data/group_expenses_repository.dart';
import '../data/group_mirror_service.dart';
import '../data/groups_repository.dart';
import '../domain/group_expense_model.dart';
import '../domain/group_model.dart';
import 'widgets/guest_sheets.dart';

class _ItemDraft {
  final TextEditingController name;
  final TextEditingController price;
  final Set<String> members;
  _ItemDraft({String name = '', String price = '', Set<String>? members})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        members = members ?? <String>{};
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

/// Add or edit a group expense (or a group recurring template).
class AddGroupExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? editId;
  final bool startRecurring;

  /// Open the camera straight away to scan a bill (widget / app shortcut).
  final bool startScan;
  const AddGroupExpenseScreen({
    super.key,
    required this.groupId,
    this.editId,
    this.startRecurring = false,
    this.startScan = false,
  });

  @override
  ConsumerState<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends ConsumerState<AddGroupExpenseScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _notes = TextEditingController();

  /// Itemized: tax / service charge and discount for the whole bill.
  final _charges = TextEditingController();
  final _discount = TextEditingController();
  final Map<String, TextEditingController> _exact = {};
  final Map<String, TextEditingController> _percent = {};
  final List<_ItemDraft> _items = [];

  GroupExpenseModel? _editing;
  bool _initialized = false;
  String? _newId;
  String? _categoryId;
  CategoryModel? _snapshotCategory;
  DateTime _date = DateTime.now();
  String? _payer;
  SplitMode _mode = SplitMode.equal;
  final Set<String> _participants = {};
  bool _recurring = false;
  RecurrenceInterval _interval = RecurrenceInterval.monthly;
  EncodedImage? _receipt;
  Uint8List? _receiptBytes;
  bool _removeReceipt = false;
  bool _saving = false;
  bool _autoPicked = false;
  bool _categoryTouched = false;
  ParsedBill? _scanned;
  bool _scanning = false;
  bool _autoScanStarted = false;
  final Map<String, GlobalKey> _chipKeys = {};

  @override
  void initState() {
    super.initState();
    _recurring = widget.startRecurring;
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    _notes.dispose();
    _charges.dispose();
    _discount.dispose();
    for (final c in [..._exact.values, ..._percent.values]) {
      c.dispose();
    }
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(Map<String, TextEditingController> map, String uid, [String initial = '']) =>
      map.putIfAbsent(uid, () => TextEditingController(text: initial)..addListener(_onSplitChanged));

  void _onSplitChanged() {
    if (mounted) setState(() {});
  }

  List<String> _people(GroupModel g) {
    final set = <String>{...g.participants};
    if (_editing != null) {
      set.addAll(_editing!.splits.keys);
      set.add(_editing!.payerUid);
    }
    return set.toList();
  }

  void _init(GroupModel group, GroupExpenseModel? existing, List<CategoryModel> cats, String me) {
    _initialized = true;
    _newId = ref.read(groupExpensesRepositoryProvider).newExpenseId(group.groupId);
    if (existing == null) {
      _payer = me;
      _participants.addAll(group.participants);
      return;
    }
    _editing = existing;
    _amount.text = Money.plain(existing.amount);
    _desc.text = existing.description;
    _notes.text = existing.notes ?? '';
    _date = existing.date;
    _payer = existing.payerUid;
    _mode = existing.splitMode;
    _recurring = existing.isRecurringTemplate;
    _interval = existing.interval ?? RecurrenceInterval.monthly;
    final resolved = CategoryResolver.resolve(
      name: existing.category,
      iconCode: existing.categoryIcon,
      colorHex: existing.categoryColor,
      categories: cats,
    );
    if (cats.any((c) => c.id == resolved.id)) {
      _categoryId = resolved.id;
    } else {
      _snapshotCategory = resolved;
      _categoryId = resolved.id;
    }
    final shares = existing.shareByUid..removeWhere((_, v) => v <= 0);
    _participants.addAll(shares.keys);
    // Seed text at creation (before listeners) — this runs during build.
    for (final e in shares.entries) {
      _ctl(_exact, e.key, Money.plain(e.value));
    }
    SplitCalculator.percentsFromShares(shares, existing.amount).forEach((uid, p) {
      _ctl(_percent, uid, p.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''));
    });
    for (final item in existing.items ?? const <GroupExpenseItemModel>[]) {
      _items.add(_ItemDraft(name: item.name, price: Money.plain(item.amount), members: item.memberUids.toSet()));
    }
    final extra = existing.itemsExtra ?? 0;
    if (extra > 0) _charges.text = Money.plain(extra);
    if (extra < 0) _discount.text = Money.plain(-extra);
  }

  /// Charges minus discount (itemized only).
  double get _extra => Money.round2(
        (Money.parse(_charges.text, allowZero: true).value ?? 0) -
            (Money.parse(_discount.text, allowZero: true).value ?? 0),
      );

  double? get _amountValue => Money.parse(_amount.text).value;

  void _onDescriptionChanged(String text, List<CategoryModel> cats) {
    if (_editing != null || _categoryTouched) return;
    final guess = ref.read(categoryGuesserProvider).guess(text);
    final before = _categoryId;
    setState(() {
      if (guess != null) {
        _categoryId = guess.category.id;
        _autoPicked = true;
      } else if (_autoPicked) {
        _categoryId = cats.isNotEmpty ? cats.first.id : CategoryModel.othersId;
        _autoPicked = false;
      }
    });
    if (_categoryId != before) _revealCategory();
  }

  void _pickCategory(String id) => setState(() {
        _categoryId = id;
        _categoryTouched = true;
        _autoPicked = false;
      });

  /// Scrolls the chip row so the (auto-)picked category is on screen.
  void _revealCategory() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[_categoryId]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Motion.base, curve: Curves.easeOutCubic);
      }
    });
  }

  SplitResult _compute() {
    final payer = _payer ?? '';
    switch (_mode) {
      case SplitMode.equal:
        return SplitCalculator.equal(total: _amountValue ?? 0, participants: _participants.toList(), payerUid: payer);
      case SplitMode.exact:
        return SplitCalculator.exact(total: _amountValue ?? 0, amounts: {
          for (final e in _exact.entries)
            if (e.value.text.trim().isNotEmpty) e.key: Money.parse(e.value.text, allowZero: true).value ?? double.nan,
        });
      case SplitMode.percent:
        return SplitCalculator.percent(total: _amountValue ?? 0, payerUid: payer, percents: {
          for (final e in _percent.entries)
            if (e.value.text.trim().isNotEmpty) e.key: double.tryParse(e.value.text.replaceAll(',', '.')) ?? double.nan,
        });
      case SplitMode.itemized:
        return SplitCalculator.itemized(payerUid: payer, extra: _extra, items: [
          for (final i in _items)
            SplitItem(
              name: i.name.text,
              amount: Money.parse(i.price.text).value ?? 0,
              memberUids: i.members.toList(),
            ),
        ]);
    }
  }

  Future<void> _save(GroupModel group, List<CategoryModel> cats) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final formOk = _form.currentState!.validate();
    final result = _compute();
    if (!formOk) return;
    if (!result.isValid) {
      Toast.show(result.error!, type: ToastType.error);
      return;
    }
    final category = _snapshotCategory != null && _categoryId == _snapshotCategory!.id
        ? _snapshotCategory!
        : cats.firstWhere((c) => c.id == _categoryId, orElse: () => CategoryModel.others);
    final now = DateTime.now();
    final previous = _editing;
    final isTemplate = previous?.isRecurringTemplate ?? _recurring;
    final model = GroupExpenseModel(
      expenseId: previous?.expenseId ?? _newId!,
      payerUid: _payer!,
      amount: result.total,
      category: category.name,
      categoryIcon: category.iconCode,
      categoryColor: category.colorHex,
      description: _desc.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      splitType: _mode.storageKey,
      splits: GroupExpenseModel.mergeSettledFlags(newShares: result.shares, newPayer: _payer!, previous: previous),
      date: previous == null && Dates.isSameDay(_date, now) ? now : _date,
      createdAt: previous?.createdAt ?? now,
      createdBy: previous?.createdBy,
      isRecurringTemplate: isTemplate,
      recurrenceInterval: isTemplate ? _interval.key : null,
      lastGeneratedDate: previous?.lastGeneratedDate,
      generatedFromTemplateId: previous?.generatedFromTemplateId,
      isCancelled: previous?.isCancelled ?? false,
      items: _mode == SplitMode.itemized
          ? [
              for (final i in _items)
                GroupExpenseItemModel(
                  name: i.name.text.trim(),
                  amount: Money.parse(i.price.text).value ?? 0,
                  memberUids: i.members.toList(),
                ),
            ]
          : null,
      itemsExtra: _mode == SplitMode.itemized && _extra != 0 ? _extra : null,
    );

    setState(() => _saving = true);
    final repo = ref.read(groupExpensesRepositoryProvider);
    try {
      final WriteOutcome outcome = previous == null
          ? await repo.addExpense(group: group, expense: model, receipt: _receipt)
          : await repo.updateExpense(
              group: group,
              previous: previous,
              updated: model,
              newReceipt: _receipt,
              removeReceipt: _removeReceipt,
            );
      final uid = ref.read(currentUidProvider);
      if (isTemplate && uid != null) {
        final engine = ref.read(recurringEngineProvider);
        final mirrors = ref.read(mirrorServiceProvider);
        // Back-filled instances must reach the payer's ledger now, not at the
        // next launch (and never, if the group is deleted before then).
        runInBackground(() async {
          await engine.run(uid);
          await mirrors.scanAll();
        }, label: 'recurring after group save');
      }
      Haptics.success();
      if (mounted) context.popOrGo('/groups/${group.groupId}');
      Toast.saved(outcome, previous == null ? (isTemplate ? 'Recurring expense set up' : 'Expense added') : 'Changes saved');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      Toast.error(e);
    }
  }

  void _chooseScanSource(GroupModel group) {
    showAppSheet<void>(
      context,
      builder: (ctx) => SheetBody(
        title: 'Scan a bill',
        subtitle: 'Read on your phone. The photo is kept as the receipt.',
        children: [
          for (final (icon, label, source) in [
            (Icons.photo_camera_rounded, 'Take a photo', ImageSource.camera),
            (Icons.photo_library_rounded, 'Choose from gallery', ImageSource.gallery),
          ])
            ListTile(
              leading: IconBadge(icon, size: 40),
              title: Text(label),
              onTap: () {
                Navigator.of(ctx).pop();
                _scanBill(group, source);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _scanBill(GroupModel group, ImageSource source) async {
    if (_scanning) return;
    final typed = _items.where((i) => i.name.text.trim().isNotEmpty || i.price.text.trim().isNotEmpty).length;
    if (_mode == SplitMode.itemized && typed > 0) {
      final ok = await confirmAction(
        context,
        title: 'Replace your items?',
        message: 'The items read from the bill will replace the $typed you added.',
        confirmLabel: 'Replace',
      );
      if (!ok || !mounted) return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _scanning = true);
    ScannedBill? scan;
    try {
      scan = await BillScanner.scan(source);
    } catch (e) {
      debugPrint('Bill scan failed: $e');
      Toast.show('Couldn\'t read that photo. Try again in good light.', type: ToastType.error);
    }
    if (!mounted) return;
    setState(() => _scanning = false);
    if (scan != null) _applyScan(scan, _people(group));
  }

  void _applyScan(ScannedBill scan, List<String> people) {
    final bill = scan.bill;
    final keepReceipt = _receiptBytes == null && !((_editing?.hasReceipt ?? false) && !_removeReceipt);
    final fillDesc = _desc.text.trim().isEmpty && bill.merchant != null;
    if (bill.isEmpty && bill.billTotal == null) {
      Toast.show('Couldn\'t find any prices. Try a flat, well-lit photo with the items and total in view.',
          type: ToastType.error, duration: const Duration(seconds: 5));
      return;
    }
    setState(() {
      if (bill.isEmpty) {
        // Items unreadable but the total is there: split the total.
        _mode = SplitMode.equal;
        _amount.text = Money.plain(bill.billTotal!);
        _scanned = null;
      } else {
        for (final i in _items) {
          i.dispose();
        }
        _items
          ..clear()
          ..addAll([
            for (final item in bill.items)
              _ItemDraft(
                name: item.name,
                price: item.amount == null ? '' : Money.plain(item.amount!),
                members: {...people},
              ),
          ]);
        _mode = SplitMode.itemized;
        _charges.text = bill.charges > 0 ? Money.plain(bill.charges) : '';
        _discount.text = bill.discount > 0 ? Money.plain(bill.discount) : '';
        _scanned = bill;
      }
      if (keepReceipt && scan.receipt != null) {
        _receipt = scan.receipt;
        _receiptBytes = scan.receiptBytes;
        _removeReceipt = false;
      }
      if (fillDesc) _desc.text = bill.merchant!;
    });
    if (fillDesc) {
      _onDescriptionChanged(_desc.text, ref.read(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults);
    }
    Haptics.success();
    if (bill.isEmpty) {
      Toast.show('Couldn\'t make out the items, so the bill total was used.',
          type: ToastType.warning, duration: const Duration(seconds: 5));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider) ?? '';
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final groupAsync = ref.watch(groupDetailsStreamProvider(widget.groupId));
    final group = groupAsync.valueOrNull;

    if (group == null) {
      return Scaffold(
        appBar: AppBar(leading: CloseButton(onPressed: () => context.popOrGo('/groups'))),
        body: Center(
          child: groupAsync.isLoading
              ? const CircularProgressIndicator()
              : const EmptyState(
                  icon: Icons.group_off_rounded,
                  title: 'This group isn\'t available',
                  message: 'It may have been deleted or you were removed.',
                ),
        ),
      );
    }

    if (!_initialized) {
      if (widget.editId == null) {
        _init(group, null, cats, me);
      } else {
        final expenses = ref.watch(groupExpensesStreamProvider(widget.groupId));
        final templates = ref.watch(groupTemplatesStreamProvider(widget.groupId));
        final found = [...?expenses.valueOrNull, ...?templates.valueOrNull]
            .where((e) => e.expenseId == widget.editId)
            .firstOrNull;
        if (found == null) {
          final loading = expenses.isLoading || templates.isLoading;
          return Scaffold(
            appBar: AppBar(leading: CloseButton(onPressed: () => context.popOrGo('/groups/${widget.groupId}'))),
            body: Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Expense not found',
                      message: 'Someone may have deleted it.',
                    ),
            ),
          );
        }
        _init(group, found, cats, me);
      }
    }
    // Same guard as the personal screen: never keep a default category id that
    // your own list (loaded a moment later) doesn't have.
    if (_editing == null && !_categoryTouched && !cats.any((c) => c.id == _categoryId)) {
      _categoryId = cats.isNotEmpty ? cats.first.id : CategoryModel.othersId;
      _autoPicked = false;
    }
    _categoryId ??= cats.isNotEmpty ? cats.first.id : CategoryModel.othersId;
    if (widget.startScan && !_autoScanStarted && _editing == null) {
      _autoScanStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanBill(group, ImageSource.camera);
      });
    }
    final categories = [...cats, if (_snapshotCategory != null) _snapshotCategory!];
    final people = _people(group);
    final result = _compute();
    final isTemplate = _editing?.isRecurringTemplate ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(onPressed: () => context.popOrGo('/groups/${group.groupId}')),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_editing == null ? 'Add expense' : (isTemplate ? 'Edit recurring' : 'Edit expense')),
            Text(group.name, style: context.text.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          if (!isTemplate)
            IconButton(
              tooltip: 'Scan a bill',
              icon: const Icon(Icons.document_scanner_rounded),
              onPressed: _scanning ? null : () => _chooseScanSource(group),
            ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 120),
              children: [
                const SizedBox(height: Space.sm),
                if (_mode == SplitMode.itemized)
                  Center(
                    child: Column(
                      children: [
                        Text(_extra == 0 ? 'Total from items' : 'Total with tax & charges', style: context.text.labelMedium),
                        Text(Money.format(result.isValid ? result.total : _itemsTotal() + _extra),
                            style: context.text.displayMedium?.copyWith(fontFeatures: AppTheme.tabular)),
                      ],
                    ),
                  )
                else
                  MoneyField(
                    controller: _amount,
                    autofocus: _editing == null,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => Money.parse(v).error,
                  ),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _desc,
                  label: 'Description',
                  hint: 'e.g. Groceries at DMart',
                  icon: Icons.edit_note_rounded,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => _onDescriptionChanged(v, cats),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Add a short description' : null,
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Text('Category', style: context.text.titleSmall),
                    if (_autoPicked) ...[
                      const SizedBox(width: Space.xs),
                      const Pill('Auto-picked', tone: PillTone.primary, icon: Icons.auto_awesome_rounded),
                    ],
                  ],
                ),
                const SizedBox(height: Space.xs),
                // A Row (not a lazy list) so every chip exists and can be scrolled to.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final cat in categories)
                        Padding(
                          key: _chipKeys.putIfAbsent(cat.id, GlobalKey.new),
                          padding: const EdgeInsets.only(right: Space.xs),
                          child: ChoiceChipX(
                            label: cat.name,
                            icon: cat.icon,
                            color: cat.color,
                            selected: cat.id == _categoryId,
                            onTap: () => _pickCategory(cat.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                Text(isTemplate || _recurring ? 'Starts on' : 'Date', style: context.text.titleSmall),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    ChoiceChipX(
                      label: 'Today',
                      selected: Dates.isSameDay(_date, DateTime.now()),
                      onTap: () => setState(() => _date = DateTime.now()),
                    ),
                    ChoiceChipX(
                      label: 'Yesterday',
                      selected: Dates.isSameDay(_date, DateTime.now().subtract(const Duration(days: 1))),
                      onTap: () => setState(() => _date = DateTime.now().subtract(const Duration(days: 1))),
                    ),
                    ChoiceChipX(
                      label: _otherDay ? Dates.dayLabel(_date) : 'Pick a date',
                      icon: Icons.calendar_month_rounded,
                      selected: _otherDay,
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date.isAfter(now) && !(isTemplate || _recurring) ? now : _date,
                          firstDate: DateTime(2015),
                          lastDate: isTemplate || _recurring ? DateTime(now.year + 1, now.month, now.day) : now,
                        );
                        if (picked != null) setState(() => _date = Dates.withTimeOf(picked, DateTime.now()));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Text('Paid by', style: context.text.titleSmall),
                const SizedBox(height: Space.xs),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: people.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
                    itemBuilder: (_, i) => i == people.length
                        ? _AddPersonPick(onTap: () async {
                            // Someone not on SplitMate yet: add them on the spot.
                            final id = await showAddGuestSheet(context, group);
                            if (id != null && mounted) setState(() => _participants.add(id));
                          })
                        : _PersonPick(
                            uid: people[i],
                            selected: people[i] == _payer,
                            onTap: () => setState(() => _payer = people[i]),
                          ),
                  ),
                ),
                const SizedBox(height: Space.lg),
                Text('Split', style: context.text.titleSmall),
                const SizedBox(height: Space.xs),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<SplitMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: SplitMode.equal, label: Text('Equal', maxLines: 1, softWrap: false)),
                      ButtonSegment(value: SplitMode.exact, label: Text('Exact', maxLines: 1, softWrap: false)),
                      ButtonSegment(value: SplitMode.percent, label: Text('%', maxLines: 1, softWrap: false)),
                      ButtonSegment(value: SplitMode.itemized, label: Text('Items', maxLines: 1, softWrap: false)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() {
                      _mode = s.first;
                      if (_mode == SplitMode.itemized && _items.isEmpty) {
                        _items.add(_ItemDraft(members: {...group.participants}));
                      }
                    }),
                  ),
                ),
                const SizedBox(height: Space.md),
                _SplitMeter(result: result, mode: _mode),
                const SizedBox(height: Space.sm),
                AnimatedSwitcher(
                  duration: Motion.base,
                  child: KeyedSubtree(key: ValueKey(_mode), child: _splitEditor(context, people, result)),
                ),
                const SizedBox(height: Space.lg),
                if (_editing == null || isTemplate)
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                    child: Column(
                      children: [
                        if (_editing == null)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _recurring,
                            onChanged: (v) => setState(() => _recurring = v),
                            secondary: const IconBadge(Icons.autorenew_rounded, size: 40),
                            title: const Text('Repeat this expense'),
                            subtitle: const Text('Rent, Wi-Fi, maid…'),
                          ),
                        if (_recurring)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.sm, top: Space.xs),
                            child: SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<RecurrenceInterval>(
                                showSelectedIcon: false,
                                segments: [
                                  for (final i in RecurrenceInterval.values) ButtonSegment(value: i, label: Text(i.label)),
                                ],
                                selected: {_interval},
                                onSelectionChanged: (s) => setState(() => _interval = s.first),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.md),
                _receiptRow(context),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _notes,
                  label: 'Notes (optional)',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                  maxLength: 200,
                ),
              ],
            ),
          ),
          if (_scanning) const Positioned.fill(child: _ScanningOverlay()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.sm),
          child: PrimaryButton(
            label: _editing == null ? 'Save expense' : 'Save changes',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: () => _save(group, cats),
          ),
        ),
      ),
    );
  }

  bool get _otherDay {
    final now = DateTime.now();
    return !Dates.isSameDay(_date, now) && !Dates.isSameDay(_date, now.subtract(const Duration(days: 1)));
  }

  double _itemsTotal() => _items.fold<double>(0, (a, i) => a + (Money.parse(i.price.text).value ?? 0));

  Widget _splitEditor(BuildContext context, List<String> people, SplitResult result) {
    final c = context.aurora;
    switch (_mode) {
      case SplitMode.equal:
        final allSelected = people.every(_participants.contains);
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => allSelected ? _participants.clear() : _participants.addAll(people)),
                child: Text(allSelected ? 'Clear all' : 'Select all'),
              ),
            ),
            for (final uid in people)
              _PersonRow(
                uid: uid,
                leading: Checkbox(
                  value: _participants.contains(uid),
                  onChanged: (v) => setState(() => v == true ? _participants.add(uid) : _participants.remove(uid)),
                ),
                trailing: Text(
                  _participants.contains(uid) && result.isValid ? Money.format(result.shares[uid] ?? 0) : '—',
                  style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular),
                ),
                onTap: () => setState(() => _participants.contains(uid) ? _participants.remove(uid) : _participants.add(uid)),
              ),
            if (result.isValid && Money.toPaise(result.total) % (_participants.isEmpty ? 1 : _participants.length) != 0)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text('Leftover paise go to the payer so it adds up exactly.', style: context.text.bodySmall),
              ),
          ],
        );
      case SplitMode.exact:
      case SplitMode.percent:
        final isPct = _mode == SplitMode.percent;
        return Column(
          children: [
            for (final uid in people)
              _PersonRow(
                uid: uid,
                subtitle: isPct && result.isValid && (result.shares[uid] ?? 0) > 0 ? Money.format(result.shares[uid]!) : null,
                trailing: SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _ctl(isPct ? _percent : _exact, uid),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: moneyInputFormatters,
                    textAlign: TextAlign.right,
                    style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0',
                      prefixText: isPct ? null : '₹ ',
                      suffixText: isPct ? '%' : null,
                    ),
                  ),
                ),
              ),
            if (isPct)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    final n = people.length;
                    if (n == 0) return;
                    final base = (10000 ~/ n) / 100;
                    for (var i = 0; i < n; i++) {
                      final v = i == n - 1 ? 100 - base * (n - 1) : base;
                      _ctl(_percent, people[i]).text = v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
                    }
                  }),
                  child: const Text('Split evenly'),
                ),
              ),
          ],
        );
      case SplitMode.itemized:
        final group = ref.read(groupDetailsStreamProvider(widget.groupId)).valueOrNull;
        return Column(
          children: [
            if (_scanned != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: _ScanSummary(
                  bill: _scanned!,
                  currentTotal: result.isValid ? result.total : _itemsTotal() + _extra,
                ),
              )
            else if (group != null && _editing == null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: SecondaryButton(
                  label: 'Scan a bill instead',
                  icon: Icons.document_scanner_rounded,
                  onPressed: () => _chooseScanSource(group),
                ),
              ),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(Space.sm),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _items[i].name,
                              onChanged: (_) => setState(() {}),
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(isDense: true, hintText: 'Item ${i + 1}'),
                            ),
                          ),
                          const SizedBox(width: Space.xs),
                          SizedBox(
                            width: 104,
                            child: TextField(
                              controller: _items[i].price,
                              onChanged: (_) => setState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: moneyInputFormatters,
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(isDense: true, hintText: '0', prefixText: '₹ '),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove item',
                            icon: Icon(Icons.close_rounded, color: c.textMuted),
                            onPressed: () => setState(() => _items.removeAt(i).dispose()),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final uid in people)
                              _MiniPersonChip(
                                uid: uid,
                                selected: _items[i].members.contains(uid),
                                onTap: () => setState(() {
                                  final m = _items[i].members;
                                  m.contains(uid) ? m.remove(uid) : m.add(uid);
                                }),
                              ),
                          ],
                        ),
                      ),
                      if (_items[i].members.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Pick who shared this', style: context.text.bodySmall?.copyWith(color: c.negative)),
                        ),
                    ],
                  ),
                ),
              ),
            SecondaryButton(
              label: 'Add item',
              icon: Icons.add_rounded,
              onPressed: () => setState(() => _items.add(_ItemDraft(members: {...people}))),
            ),
            const SizedBox(height: Space.sm),
            AppCard(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExtraRow(label: 'Tax & charges', hint: 'GST, service…', controller: _charges, onChanged: _onSplitChanged),
                  _ExtraRow(label: 'Discount', controller: _discount, onChanged: _onSplitChanged),
                  const SizedBox(height: 4),
                  Text('Shared in proportion to what each person had.', style: context.text.bodySmall),
                ],
              ),
            ),
            if (result.isValid) ...[
              const SizedBox(height: Space.md),
              for (final e in result.shares.entries)
                _PersonRow(
                  uid: e.key,
                  trailing: Text(Money.format(e.value),
                      style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular)),
                ),
            ],
          ],
        );
    }
  }

  Widget _receiptRow(BuildContext context) {
    final c = context.aurora;
    final hasExisting = (_editing?.hasReceipt ?? false) && !_removeReceipt && _receipt == null;
    if (_receiptBytes != null || hasExisting) {
      return AppCard(
        padding: const EdgeInsets.all(Space.sm),
        child: Row(
          children: [
            if (_receiptBytes != null)
              ClipRRect(
                borderRadius: Radii.chip,
                child: Image.memory(_receiptBytes!, width: 52, height: 52, fit: BoxFit.cover, cacheWidth: 156),
              )
            else
              const IconBadge(Icons.receipt_long_rounded, size: 48),
            const SizedBox(width: Space.sm),
            const Expanded(child: Text('Receipt attached')),
            IconButton(
              tooltip: 'Remove receipt',
              icon: Icon(Icons.delete_outline_rounded, color: c.negative),
              onPressed: () => setState(() {
                _receipt = null;
                _receiptBytes = null;
                _removeReceipt = true;
              }),
            ),
          ],
        ),
      );
    }
    return SecondaryButton(
      label: 'Attach receipt',
      icon: Icons.add_a_photo_outlined,
      onPressed: () => showAppSheet<void>(
        context,
        builder: (ctx) => SheetBody(
          title: 'Add a receipt',
          children: [
            for (final (icon, label, source) in [
              (Icons.photo_camera_rounded, 'Take a photo', ImageSource.camera),
              (Icons.photo_library_rounded, 'Choose from gallery', ImageSource.gallery),
            ])
              ListTile(
                leading: IconBadge(icon, size: 40),
                title: Text(label),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final img = await ImageCodec.pick(source: source);
                    if (img == null || !mounted) return;
                    setState(() {
                      _receipt = img;
                      _receiptBytes = ImageCodec.decode(img.base64);
                      _removeReceipt = false;
                    });
                  } catch (e) {
                    Toast.error(e);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Live "₹X left to assign" / "All assigned" meter.
class _SplitMeter extends StatelessWidget {
  final SplitResult result;
  final SplitMode mode;
  const _SplitMeter({required this.result, required this.mode});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final ok = result.isValid;
    final color = ok ? c.positive : (result.remaining < 0 ? c.negative : c.warning);
    final text = ok
        ? (mode == SplitMode.equal
            ? '${result.shares.length} ${result.shares.length == 1 ? 'person' : 'people'} · adds up to ${Money.format(result.total)}'
            : 'All assigned · ${Money.format(result.total)}')
        : result.error!;
    return AnimatedContainer(
      duration: Motion.base,
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: Radii.tile),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.info_rounded, color: color, size: 20),
          const SizedBox(width: Space.xs),
          Expanded(child: Text(text, style: context.text.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _PersonRow extends ConsumerWidget {
  final String uid;
  final Widget? leading;
  final Widget trailing;
  final String? subtitle;
  final VoidCallback? onTap;
  const _PersonRow({required this.uid, required this.trailing, this.leading, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (leading != null) leading!,
            UserAvatar(uid: uid, size: 36),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.watch(memberNameProvider(uid)),
                      style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _AddPersonPick extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPersonPick({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return Semantics(
      button: true,
      label: 'Add someone without the app',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(3),
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.textMuted, width: 2)),
                child: Icon(Icons.person_add_alt_1_rounded, color: c.textMuted),
              ),
              const SizedBox(height: 4),
              Text('Add', style: context.text.labelMedium?.copyWith(color: c.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonPick extends ConsumerWidget {
  final String uid;
  final bool selected;
  final VoidCallback onTap;
  const _PersonPick({required this.uid, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? c.primary : Colors.transparent, width: 2.5),
                ),
                child: UserAvatar(uid: uid, size: 48),
              ),
              const SizedBox(height: 4),
              Text(
                ref.watch(memberNameProvider(uid)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                  color: selected ? c.primary : c.textMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPersonChip extends ConsumerWidget {
  final String uid;
  final bool selected;
  final VoidCallback onTap;
  const _MiniPersonChip({required this.uid, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
        decoration: BoxDecoration(
          color: selected ? c.primary.withValues(alpha: 0.16) : c.surfaceHigh,
          borderRadius: Radii.round,
          border: Border.all(color: selected ? c.primary.withValues(alpha: 0.6) : c.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(opacity: selected ? 1 : 0.5, child: UserAvatar(uid: uid, size: 22)),
            const SizedBox(width: 6),
            Text(ref.watch(memberNameProvider(uid)),
                style: context.text.labelMedium?.copyWith(color: selected ? c.primary : c.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// "Reading the bill…" over the form while ML Kit works.
class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay();

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return ColoredBox(
      color: c.ink.withValues(alpha: 0.35),
      child: Center(
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: Space.md),
              Text('Reading the bill…', style: context.text.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether the scanned items add up to the bill's printed total.
class _ScanSummary extends StatelessWidget {
  final ParsedBill bill;
  final double currentTotal;
  const _ScanSummary({required this.bill, required this.currentTotal});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final printed = bill.billTotal;
    final ok = printed != null && Money.equals(printed, currentTotal);
    final color = ok ? c.positive : c.warning;
    final n = bill.items.length;
    final items = '$n ${n == 1 ? 'item' : 'items'}';
    final headline = ok
        ? 'Read $items. Matches the bill: ${Money.format(printed)}'
        : printed != null
            ? 'The bill says ${Money.format(printed)}, these add up to ${Money.format(currentTotal)}. '
                'Check for a missed or misread line.'
            : 'Read $items. No total found, so check them against the bill.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: Radii.tile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: color, size: 20),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(headline,
                    style: context.text.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text('Tap the names under each item to set who had what.', style: context.text.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _ExtraRow({required this.label, required this.controller, required this.onChanged, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (hint != null) Text(hint!, style: context.text.bodySmall),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              textAlign: TextAlign.right,
              style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular),
              decoration: const InputDecoration(isDense: true, hintText: '0', prefixText: '₹ '),
            ),
          ),
        ],
      ),
    );
  }
}
