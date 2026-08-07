import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';
import '../../../core/utils/recurring_engine.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? editExpenseId;
  const AddExpenseScreen({super.key, this.editExpenseId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;

  bool _initialized = false;
  bool _isRecurring = false;
  String _recurrenceInterval = 'weekly';
  String? _receiptUrl;

  @override
  void initState() {
    super.initState();
    if (widget.editExpenseId != null) {
      _loadExpenseDetails();
    }
  }

  Future<void> _loadExpenseDetails() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(widget.editExpenseId)
          .get();
      if (doc.exists && mounted) {
        final expense = ExpenseModel.fromMap(doc.data()!, doc.id);
        setState(() {
          _amountController.text = expense.amount.toStringAsFixed(2);
          _descriptionController.text = expense.description;
          _selectedCategoryId = expense.category;
          _selectedDate = expense.createdAt;
          _receiptUrl = expense.receiptUrl;
          _isRecurring = expense.isRecurringTemplate;
          _recurrenceInterval = expense.recurrenceInterval ?? 'weekly';
          _initialized = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _receiptUrl = 'data:image/jpeg;base64,$base64String';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach image: $e'), backgroundColor: AppTheme.semanticNegative),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accent,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceCard,
              onSurface: AppTheme.textPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppTheme.surfaceBase,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryId == null) {
      setState(() {
        _errorMessage = 'Please select a category';
      });
      return;
    }

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid amount greater than 0';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final expense = ExpenseModel(
        id: widget.editExpenseId ?? const Uuid().v4(),
        amount: amount,
        category: _selectedCategoryId!,
        description: _descriptionController.text.trim(),
        createdAt: _selectedDate,
        receiptUrl: _receiptUrl,
        isRecurringTemplate: _isRecurring,
        recurrenceInterval: _isRecurring ? _recurrenceInterval : null,
        lastGeneratedDate: null,
        isCancelled: false,
      );

      if (widget.editExpenseId != null) {
        await ref.read(expenseRepositoryProvider).updateExpense(widget.editExpenseId!, expense);
      } else {
        await ref.read(expenseRepositoryProvider).addExpense(expense);
      }

      if (_isRecurring) {
        await processRecurringTemplates(ref);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(userCategoriesProvider);

    if (widget.editExpenseId != null && !_initialized) {
      return const Scaffold(
        backgroundColor: AppTheme.surfaceBase,
        body: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.editExpenseId != null ? 'EDIT ENTRY' : 'ADD ENTRY',
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
          data: (categories) => _buildForm(categories),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  Widget _buildForm(List<CategoryModel> categories) {
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    final formattedDate = DateFormat('MMMM dd, yyyy').format(_selectedDate);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.semanticNegative.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.semanticNegative),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTheme.monoStyle.copyWith(
                      color: AppTheme.semanticNegative,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Amount Input Field
              Text(
                'AMOUNT (INR)',
                style: AppTheme.monoSecondary.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTheme.monoStyle.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                cursorColor: AppTheme.accent,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  if (double.tryParse(val.trim()) == null) {
                    return 'Enter a valid decimal number';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.surfaceCard,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '₹',
                      style: TextStyle(color: AppTheme.accent, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
                  errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.semanticNegative),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.semanticNegative, width: 1.5),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Description Input Field
              _buildTextField(
                label: 'DESCRIPTION / PAYEE',
                controller: _descriptionController,
                hintText: 'Whole Foods Market',
              ),
              const SizedBox(height: 24),

              // Date Selection Row
              Text(
                'DATE',
                style: AppTheme.monoSecondary.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                      ),
                      const Icon(Icons.calendar_today_outlined, color: AppTheme.accent, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Receipt / Bill Image Picker Section
              _buildReceiptSection(),
              const SizedBox(height: 24),

              // Make Recurring Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MAKE RECURRING',
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Switch(
                    value: _isRecurring,
                    onChanged: (val) {
                      setState(() {
                        _isRecurring = val;
                      });
                    },
                    activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
                    inactiveThumbColor: AppTheme.textSecondary,
                    inactiveTrackColor: AppTheme.surfaceCard,
                  ),
                ],
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _recurrenceInterval,
                      dropdownColor: AppTheme.surfaceBase,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('WEEKLY'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('MONTHLY'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _recurrenceInterval = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Category Selector Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SELECT CATEGORY',
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push('/categories'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'MANAGE',
                        style: AppTheme.monoStyle.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'No categories available.',
                          style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => context.push('/categories'),
                          child: Text(
                            'CREATE A CATEGORY',
                            style: AppTheme.monoStyle.copyWith(
                              fontSize: 12,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategoryId == category.id;
                    final color = category.color;
                    final icon = category.icon;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category.id;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.surfaceCard,
                          border: Border.all(
                            color: isSelected ? color : AppTheme.textSecondary.withValues(alpha: 0.2),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? color : AppTheme.textSecondary,
                              size: 26,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category.name.toUpperCase(),
                              style: AppTheme.monoStyle.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 40),

              // Save Button
              InkWell(
                onTap: _isLoading ? null : _handleSave,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                  ),
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            widget.editExpenseId != null ? 'SAVE CHANGES' : 'ADD TO LEDGER',
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
      ),
    );
  }

  Widget _buildReceiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACH RECEIPT / BILL PHOTO',
          style: AppTheme.monoSecondary.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        if (_receiptUrl != null && _receiptUrl!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  color: Colors.black,
                  child: const Icon(Icons.receipt_long, color: AppTheme.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECEIPT ATTACHED',
                        style: AppTheme.monoStyle.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bill photo saved with entry',
                        style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.semanticNegative),
                  onPressed: () {
                    setState(() {
                      _receiptUrl = null;
                    });
                  },
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: () => _pickReceiptImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(
                    'TAKE PHOTO',
                    style: AppTheme.monoStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: () => _pickReceiptImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(
                    'GALLERY',
                    style: AppTheme.monoStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.monoSecondary.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceCard,
            hintText: hintText,
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
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.semanticNegative),
              borderRadius: BorderRadius.zero,
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.semanticNegative, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ],
    );
  }
}
