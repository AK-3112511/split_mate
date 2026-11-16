import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../data/categories_repository.dart';
import '../domain/category_model.dart';
import '../domain/category_resolver.dart';

/// Create or edit a category (name, icon, colour, optional monthly budget).
/// Returns the saved category, or null when cancelled.
Future<CategoryModel?> showCategoryEditor(BuildContext context, {CategoryModel? existing}) {
  return showAppSheet<CategoryModel>(context, builder: (_) => _CategoryEditor(existing: existing));
}

class _CategoryEditor extends ConsumerStatefulWidget {
  final CategoryModel? existing;
  const _CategoryEditor({this.existing});

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _budget = TextEditingController(
    text: widget.existing?.monthlyBudget == null ? '' : Money.plain(widget.existing!.monthlyBudget!),
  );
  late String _icon = widget.existing?.iconCode ?? 'restaurant';
  late String _color = widget.existing?.colorHex ?? CategoryModel.palette.first;
  bool _iconTouched = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) _iconTouched = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final budgetText = _budget.text.trim();
    final budget = budgetText.isEmpty ? null : Money.parse(budgetText).value;
    setState(() => _saving = true);
    final repo = ref.read(categoriesRepositoryProvider);
    try {
      CategoryModel saved;
      if (widget.existing == null) {
        saved = await repo.add(name: _name.text, iconCode: _icon, colorHex: _color, monthlyBudget: budget);
      } else {
        saved = widget.existing!.copyWith(
          name: _name.text.trim(),
          iconCode: _icon,
          colorHex: _color,
          monthlyBudget: budget,
          clearBudget: budget == null,
        );
        await repo.update(saved);
      }
      if (mounted) Navigator.of(context).pop(saved);
      Toast.success(widget.existing == null ? 'Category added' : 'Category updated');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final preview = CategoryModel(id: 'preview', name: _name.text, iconCode: _icon, colorHex: _color);
    return SheetBody(
      title: widget.existing == null ? 'New category' : 'Edit category',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: Motion.base,
                    child: CategoryBubble(preview, key: ValueKey('$_icon$_color'), size: 56),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: AppTextField(
                      controller: _name,
                      label: 'Name',
                      hint: 'e.g. Coffee',
                      maxLength: 24,
                      textCapitalization: TextCapitalization.words,
                      autofocus: widget.existing == null,
                      onChanged: (v) {
                        if (!_iconTouched) setState(() => _icon = CategoryResolver.guessIcon(v));
                      },
                      validator: (v) => (v?.trim().isEmpty ?? true) ? 'Give it a name' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              AppTextField(
                controller: _budget,
                label: 'Monthly budget (optional)',
                hint: 'e.g. 5000',
                icon: Icons.savings_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: moneyInputFormatters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return Money.parse(v).error;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Text('Colour', style: context.text.labelLarge),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final hex in CategoryModel.palette)
              Semantics(
                selected: hex == _color,
                button: true,
                label: 'Colour',
                child: GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CategoryModel.colorFromHex(hex),
                      shape: BoxShape.circle,
                      border: Border.all(color: hex == _color ? c.text : Colors.transparent, width: 3),
                    ),
                    child: hex == _color ? Icon(Icons.check_rounded, color: c.onPop, size: 20) : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Text('Icon', style: context.text.labelLarge),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final code in CategoryModel.pickableIcons)
              GestureDetector(
                onTap: () => setState(() {
                  _icon = code;
                  _iconTouched = true;
                }),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: code == _icon ? CategoryModel.colorFromHex(_color).withValues(alpha: 0.2) : c.surfaceHigh,
                    borderRadius: Radii.chip,
                    border: Border.all(
                      color: code == _icon ? CategoryModel.colorFromHex(_color) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(CategoryModel.iconMap[code],
                      color: code == _icon ? CategoryModel.colorFromHex(_color) : c.textMuted, size: 22),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: widget.existing == null ? 'Add category' : 'Save changes', loading: _saving, onPressed: _save),
      ],
    );
  }
}
