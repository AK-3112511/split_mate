import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/domain/recurrence.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/image_codec.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/recurring_engine.dart';
import '../../../core/utils/write_helper.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../../../shared_widgets/motion.dart';
import '../../../shared_widgets/receipt_viewer.dart';
import '../../../shared_widgets/states.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/data/category_guesser_provider.dart';
import '../../categories/domain/category_guesser.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/domain/category_resolver.dart';
import '../../categories/presentation/category_editor_sheet.dart';
import '../../home/domain/home_stats.dart';
import '../../receipts/data/receipts_repository.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';
import '../../../core/l10n/strings.dart';

/// Add a personal expense / recurring template, or edit one ([editId]).
class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? editId;
  final bool startRecurring;
  const AddExpenseScreen({super.key, this.editId, this.startRecurring = false});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _notes = TextEditingController();
  final _amountFocus = FocusNode();

  ExpenseModel? _editing;
  bool _initialized = false;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _recurring = false;
  RecurrenceInterval _interval = RecurrenceInterval.monthly;
  EncodedImage? _newReceipt;
  Uint8List? _newReceiptBytes;
  bool _removeReceipt = false;
  bool _showNotes = false;
  bool _saving = false;

  /// The category was set by the guesser (not by a tap), so typing may change it.
  bool _autoPicked = false;

  /// The user chose a category themselves: stop guessing.
  bool _categoryTouched = false;

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _recurring = widget.startRecurring;
    if (!_isEdit) {
      // Opened from the widget or a shortcut, the window may not have focus
      // yet when autofocus asks for the keyboard, and Android ignores that.
      // Ask again once it has settled (unless you've moved to another field).
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        final focused = FocusManager.instance.primaryFocus;
        if (focused == null || focused == _amountFocus || focused is FocusScopeNode) {
          _amountFocus.requestFocus();
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        }
      });
    }
  }

  @override
  void dispose() {
    _amountFocus.dispose();
    _amount.dispose();
    _desc.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _initFrom(ExpenseModel e, List<CategoryModel> cats) {
    _editing = e;
    _amount.text = Money.plain(e.amount);
    _desc.text = e.description;
    _notes.text = e.notes ?? '';
    _showNotes = _notes.text.isNotEmpty;
    _categoryId = CategoryResolver.resolve(id: e.categoryId, name: e.categoryName, categories: cats).id;
    _date = e.date;
    _recurring = e.isRecurringTemplate;
    _interval = e.interval ?? RecurrenceInterval.monthly;
    _initialized = true;
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final img = await ImageCodec.pick(source: source);
      if (img == null || !mounted) return;
      setState(() {
        _newReceipt = img;
        _newReceiptBytes = ImageCodec.decode(img.base64);
        _removeReceipt = false;
      });
    } catch (e) {
      Toast.error(e);
    }
  }

  void _chooseReceiptSource() {
    showAppSheet<void>(
      context,
      builder: (ctx) => SheetBody(
        title: context.s.addReceipt,
        children: [
          ListTile(
            leading: const IconBadge(Icons.photo_camera_rounded, size: 40),
            title: Text(context.s.takePhoto),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickReceipt(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const IconBadge(Icons.photo_library_rounded, size: 40),
            title: Text(context.s.chooseGallery),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickReceipt(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  void _onDescriptionChanged(String text, List<CategoryModel> cats) {
    if (_isEdit || _categoryTouched) return;
    final guess = ref.read(categoryGuesserProvider).guess(text);
    setState(() {
      if (guess != null) {
        _categoryId = guess.category.id;
        _autoPicked = true;
      } else if (_autoPicked) {
        _categoryId = cats.isNotEmpty ? cats.first.id : CategoryModel.othersId;
        _autoPicked = false;
      }
    });
  }

  void _applyQuickPick(QuickPick pick) {
    Haptics.tap();
    setState(() {
      _desc.text = pick.description;
      _categoryId = pick.category.id;
      _autoPicked = true;
      if (pick.amount != null && _amount.text.trim().isEmpty) _amount.text = Money.plain(pick.amount!);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) && !_recurring ? now : _date,
      firstDate: DateTime(2015),
      // Expenses can't be in the future; recurring templates may start later.
      lastDate: _recurring ? DateTime(now.year + 1, now.month, now.day) : now,
    );
    if (picked != null) setState(() => _date = Dates.withTimeOf(picked, DateTime.now()));
  }

  Future<void> _save(List<CategoryModel> cats) async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final amount = Money.parse(_amount.text).value!;
    final category = cats.firstWhere((c) => c.id == _categoryId, orElse: () => CategoryModel.others);
    final repo = ref.read(expenseRepositoryProvider);
    final now = DateTime.now();
    final date = Dates.isSameDay(_date, now) && !_isEdit ? now : _date;

    setState(() => _saving = true);
    try {
      final before = (ref.read(personalExpensesProvider).valueOrNull ?? const <ExpenseModel>[])
          .where((e) => e.id != _editing?.id)
          .toList();
      WriteOutcome outcome;
      if (_editing == null) {
        final expense = ExpenseModel(
          id: repo.newId(),
          amount: amount,
          categoryId: category.id,
          categoryName: category.name,
          description: _desc.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          date: date,
          createdAt: now,
          isRecurringTemplate: _recurring,
          recurrenceInterval: _recurring ? _interval.key : null,
        );
        outcome = await repo.add(expense, receipt: _newReceipt);
      } else {
        final updated = _editing!.copyWith(
          amount: amount,
          categoryId: category.id,
          categoryName: category.name,
          description: _desc.text.trim(),
          notes: _notes.text.trim(),
          date: date,
          recurrenceInterval: _editing!.isRecurringTemplate ? _interval.key : null,
        );
        outcome = await repo.update(updated, newReceipt: _newReceipt, removeReceipt: _removeReceipt);
      }

      final uid = ref.read(currentUidProvider);
      if (_recurring && uid != null) {
        final engine = ref.read(recurringEngineProvider);
        runInBackground(() => engine.run(uid), label: 'recurring after save');
      }
      final alert = _recurring
          ? null
          : HomeStats.budgetAlert(before: before, category: category, added: amount, date: date, cats: cats);
      Haptics.success();
      if (mounted) context.popOrGo();
      if (alert != null) {
        Toast.show(alert, type: ToastType.warning, duration: const Duration(seconds: 5));
      } else {
        Toast.saved(outcome, _editing == null ? (_recurring ? 'Recurring expense set up' : S.current.expenseAdded) : S.current.changesSaved);
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;

    if (_isEdit && !_initialized) {
      final list = ref.watch(personalExpensesProvider);
      final templates = ref.watch(personalTemplatesProvider);
      final loading = list.isLoading || templates.isLoading;
      final found = [...?list.valueOrNull, ...?templates.valueOrNull].where((e) => e.id == widget.editId).firstOrNull;
      if (found != null) {
        _initFrom(found, cats);
      } else {
        return Scaffold(
          appBar: AppBar(title: Text(context.s.editExpense)),
          body: Center(
            child: loading
                ? const CircularProgressIndicator()
                : const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Expense not found',
                    message: 'It may have been deleted.',
                  ),
          ),
        );
      }
    }
    // Until your profile loads, `cats` are the built-in defaults. Opened from
    // a shortcut on a cold start, a default id your list doesn't have must not
    // stick: it would save as "Other".
    if (!_isEdit && !_categoryTouched && !cats.any((c) => c.id == _categoryId)) {
      _categoryId = cats.isNotEmpty ? cats.first.id : CategoryModel.othersId;
      _autoPicked = false;
    }
    _categoryId ??= cats.isNotEmpty ? cats.first.id : CategoryModel.othersId;
    final isTemplate = _editing?.isRecurringTemplate ?? false;
    final title = _isEdit
        ? (isTemplate ? context.s.editRecurring : context.s.editExpense)
        : (_recurring ? context.s.newRecurring : context.s.newExpense);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: context.s.close,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.popOrGo(),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 120),
          children: [
            const SizedBox(height: Space.md),
            MoneyField(
              controller: _amount,
              focusNode: _amountFocus,
              autofocus: !_isEdit,
              textInputAction: TextInputAction.next,
              validator: (v) => Money.parse(v).error,
            ).entrance(context),
            const SizedBox(height: Space.lg),
            AppTextField(
              controller: _desc,
              label: context.s.whatFor,
              hint: 'e.g. Dinner at Toit',
              icon: Icons.edit_note_rounded,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (v) => _onDescriptionChanged(v, cats),
              // Amount, "Uber", Done → saved. The category is guessed as you type.
              onSubmitted: _saving ? null : (_) => _save(cats),
              validator: (v) => (v?.trim().isEmpty ?? true) ? context.s.addDescription : null,
            ).entrance(context, index: 1),
            if (!_isEdit && _desc.text.isEmpty) _QuickPicks(onPick: _applyQuickPick),
            const SizedBox(height: Space.xl),
            Row(
              children: [
                Text(context.s.category, style: context.text.titleSmall),
                if (_autoPicked) ...[
                  const SizedBox(width: Space.xs),
                  Pill(context.s.autoPicked, tone: PillTone.primary, icon: Icons.auto_awesome_rounded),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final created = await showCategoryEditor(context);
                    if (created != null && mounted) {
                      setState(() {
                        _categoryId = created.id;
                        _categoryTouched = true;
                        _autoPicked = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.s.newLabel),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            _CategoryGrid(
              categories: cats,
              selectedId: _categoryId,
              onSelect: (id) => setState(() {
                _categoryId = id;
                _categoryTouched = true;
                _autoPicked = false;
              }),
            ).entrance(context, index: 2),
            const SizedBox(height: Space.xl),
            Text(_recurring ? context.s.startsOn : context.s.date, style: context.text.titleSmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                ChoiceChipX(
                  label: context.s.today,
                  selected: Dates.isSameDay(_date, DateTime.now()),
                  onTap: () => setState(() => _date = DateTime.now()),
                ),
                ChoiceChipX(
                  label: context.s.yesterday,
                  selected: Dates.isSameDay(_date, DateTime.now().subtract(const Duration(days: 1))),
                  onTap: () => setState(() => _date = DateTime.now().subtract(const Duration(days: 1))),
                ),
                ChoiceChipX(
                  label: _isOther(_date) ? Dates.dayLabel(_date) : context.s.pickDate,
                  icon: Icons.calendar_month_rounded,
                  selected: _isOther(_date),
                  onTap: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            if (!_isEdit || isTemplate)
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                child: Column(
                  children: [
                    if (!_isEdit)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _recurring,
                        onChanged: (v) => setState(() => _recurring = v),
                        secondary: const IconBadge(Icons.autorenew_rounded, size: 40),
                        title: Text(context.s.repeatExpense),
                        subtitle: Text(context.s.repeatHint),
                      ),
                    AnimatedSize(
                      duration: Motion.base,
                      child: _recurring
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: Space.sm, top: Space.xs),
                              child: SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<RecurrenceInterval>(
                                  showSelectedIcon: false,
                                  segments: [
                                    for (final i in RecurrenceInterval.values)
                                      ButtonSegment(value: i, label: Text(i.label)),
                                  ],
                                  selected: {_interval},
                                  onSelectionChanged: (s) => setState(() => _interval = s.first),
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            if (!_isEdit || isTemplate) const SizedBox(height: Space.md),
            _receiptSection(context),
            const SizedBox(height: Space.md),
            AnimatedSize(
              duration: Motion.base,
              child: _showNotes
                  ? AppTextField(
                      controller: _notes,
                      label: context.s.notes,
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showNotes = true),
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        label: Text(context.s.addNote),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.sm),
          child: PrimaryButton(
            label: _isEdit ? context.s.saveChanges : (_recurring ? context.s.setUpRecurring : context.s.saveExpense),
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: () => _save(cats),
          ),
        ),
      ),
    );
  }

  bool _isOther(DateTime d) {
    final now = DateTime.now();
    return !Dates.isSameDay(d, now) && !Dates.isSameDay(d, now.subtract(const Duration(days: 1)));
  }

  Widget _receiptSection(BuildContext context) {
    final c = context.aurora;
    final hasExisting = (_editing?.hasReceipt ?? false) && !_removeReceipt && _newReceipt == null;
    if (_newReceiptBytes != null) {
      return AppCard(
        padding: const EdgeInsets.all(Space.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: Radii.chip,
              child: Image.memory(_newReceiptBytes!, width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 168),
            ),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(context.s.receiptAttached)),
            IconButton(
              tooltip: 'Remove receipt',
              icon: Icon(Icons.close_rounded, color: c.negative),
              onPressed: () => setState(() {
                _newReceipt = null;
                _newReceiptBytes = null;
              }),
            ),
          ],
        ),
      );
    }
    if (hasExisting) {
      return AppCard(
        padding: const EdgeInsets.all(Space.sm),
        child: Row(
          children: [
            const IconBadge(Icons.receipt_long_rounded, size: 48),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(context.s.receiptAttached)),
            TextButton(
              onPressed: () => ReceiptViewer.show(
                context,
                receipt: ReceiptRef(receiptId: _editing!.receiptId, legacy: _editing!.legacyReceipt),
                title: _editing!.description,
              ),
              child: const Text('View'),
            ),
            IconButton(
              tooltip: 'Remove receipt',
              icon: Icon(Icons.delete_outline_rounded, color: c.negative),
              onPressed: () => setState(() => _removeReceipt = true),
            ),
          ],
        ),
      );
    }
    return SecondaryButton(
      label: context.s.attachReceipt,
      icon: Icons.add_a_photo_outlined,
      onPressed: _chooseReceiptSource,
    );
  }
}

/// "Add again" chips: your most frequent recent expenses.
class _QuickPicks extends ConsumerWidget {
  final ValueChanged<QuickPick> onPick;
  const _QuickPicks({required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picks = ref.watch(categoryGuesserProvider).quickPicks();
    if (picks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: picks.length,
          separatorBuilder: (_, __) => const SizedBox(width: Space.xs),
          itemBuilder: (_, i) {
            final p = picks[i];
            return ChoiceChipX(
              label: p.amount == null ? p.description : '${p.description} · ${Money.format(p.amount!)}',
              icon: p.category.icon,
              selected: false,
              onTap: () => onPick(p),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _CategoryGrid({required this.categories, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 92,
        mainAxisSpacing: Space.xs,
        crossAxisSpacing: Space.xs,
        childAspectRatio: 0.78,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        final selected = cat.id == selectedId;
        return Semantics(
          selected: selected,
          button: true,
          label: cat.name,
          child: GestureDetector(
            onTap: () {
              Haptics.tap();
              onSelect(cat.id);
            },
            child: AnimatedContainer(
              duration: Motion.fast,
              margin: const EdgeInsets.only(right: 3, bottom: 3),
              padding: const EdgeInsets.all(Space.xs),
              decoration: BoxDecoration(
                color: selected ? c.cta : c.surface,
                borderRadius: Radii.tile,
                border: Border.all(color: c.ink, width: Brutal.borderThin),
                boxShadow: selected ? c.hardShadow(Brutal.shadowSmall) : const [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CategoryBubble(cat, size: 38),
                  const SizedBox(height: 6),
                  Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: selected ? c.onPop : c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
