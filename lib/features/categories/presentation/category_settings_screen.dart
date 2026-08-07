import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../data/categories_repository.dart';
import '../domain/category_model.dart';

class CategorySettingsScreen extends ConsumerStatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  ConsumerState<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends ConsumerState<CategorySettingsScreen> {
  final List<String> _colorPalette = [
    'C9A24B', // Gold
    '6FA88A', // Olive Green
    'C0645A', // Muted Crimson
    '8B8F94', // Slate Gray
    'A98242', // Warm Bronze
    '8E6B2C', // Deep Bronze
    '4F8E80', // Muted Teal
    '5D7E8E', // Muted Blue
  ];

  final List<String> _iconCodes = [
    'restaurant',
    'home',
    'directions_car',
    'movie',
    'electrical_services',
    'shopping_bag',
    'flight',
    'work',
    'school',
    'health_and_safety',
    'sports_esports',
    'miscellaneous_services',
  ];

  void _showCategoryForm({CategoryModel? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final nameController = TextEditingController(text: isEditing ? categoryToEdit.name : '');
    String selectedIconCode = isEditing ? categoryToEdit.iconCode : _iconCodes.first;
    String selectedColorHex = isEditing ? categoryToEdit.colorHex : _colorPalette.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // sharp square corners
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'EDIT CATEGORY' : 'CREATE CATEGORY',
                          style: AppTheme.monoStyle.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (isEditing)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.semanticNegative),
                            onPressed: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);

                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: AppTheme.surfaceCard,
                                  title: Text(
                                    'Delete Category?',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  content: const Text(
                                    'Expenses linked to this category will show as "Others". This action is permanent.',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text('CANCEL', style: AppTheme.monoSecondary),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(
                                        'DELETE',
                                        style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && mounted) {
                                try {
                                  await ref
                                      .read(categoriesRepositoryProvider)
                                      .deleteCategory(categoryToEdit);
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Category deleted successfully'),
                                      backgroundColor: AppTheme.accent,
                                    ),
                                  );
                                  navigator.pop(); // close bottom sheet
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                      backgroundColor: AppTheme.semanticNegative,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Name Field
                    Text(
                      'CATEGORY NAME',
                      style: AppTheme.monoSecondary.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                      cursorColor: AppTheme.accent,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        hintText: 'Food & Dining',
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.zero,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Color Selector
                    Text(
                      'THEME COLOR',
                      style: AppTheme.monoSecondary.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colorPalette.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final hex = _colorPalette[index];
                          final color = Color(int.parse('FF$hex', radix: 16));
                          final isSelected = selectedColorHex == hex;

                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedColorHex = hex;
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : Border.all(color: Colors.transparent),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Icon Selector Grid
                    Text(
                      'SELECT ICON',
                      style: AppTheme.monoSecondary.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _iconCodes.length,
                      itemBuilder: (context, index) {
                        final code = _iconCodes[index];
                        final icon = CategoryModel.iconMap[code] ?? Icons.category;
                        final isSelected = selectedIconCode == code;
                        final activeColor = Color(int.parse('FF$selectedColorHex', radix: 16));

                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedIconCode = code;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? activeColor.withValues(alpha: 0.1) : AppTheme.surfaceCard,
                              border: Border.all(
                                color: isSelected ? activeColor : AppTheme.textSecondary.withValues(alpha: 0.2),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: isSelected ? activeColor : AppTheme.textSecondary,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    InkWell(
                      onTap: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a category name'),
                              backgroundColor: AppTheme.semanticNegative,
                            ),
                          );
                          return;
                        }

                        final newCat = CategoryModel(
                          id: isEditing ? categoryToEdit.id : const Uuid().v4(),
                          name: name,
                          iconCode: selectedIconCode,
                          colorHex: selectedColorHex,
                        );

                        try {
                          if (isEditing) {
                            await ref
                                .read(categoriesRepositoryProvider)
                                .updateCategory(categoryToEdit, newCat);
                          } else {
                            await ref.read(categoriesRepositoryProvider).addCategory(newCat);
                          }
                          if (mounted) {
                            navigator.pop(); // close bottom sheet
                          }
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to save category: $e'),
                              backgroundColor: AppTheme.semanticNegative,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                        ),
                        child: Center(
                          child: Text(
                            isEditing ? 'UPDATE CATEGORY' : 'ADD CATEGORY',
                            style: AppTheme.monoStyle.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(userCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'MANAGE CATEGORIES',
          style: AppTheme.monoStyle.copyWith(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 15,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
            color: AppTheme.textSecondary.withValues(alpha: 0.1),
            height: 1.0,
            thickness: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: categoriesAsync.when(
          data: (categories) => _buildCategoryList(categories),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: InkWell(
          onTap: () => _showCategoryForm(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent),
              color: Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'CREATE NEW CATEGORY',
                  style: AppTheme.monoStyle.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          'No custom categories found.',
          style: AppTheme.monoSecondary.copyWith(fontSize: 14),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (context, index) => Divider(
              color: AppTheme.textSecondary.withValues(alpha: 0.15),
              height: 1.0,
              thickness: 1.0,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              final color = category.color;
              final icon = category.icon;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(
                  category.name.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'HEX: #${category.colorHex.toUpperCase()}',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                  onPressed: () => _showCategoryForm(categoryToEdit: category),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
