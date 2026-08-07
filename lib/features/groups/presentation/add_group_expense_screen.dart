import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../friends/data/friends_repository.dart';
import '../data/group_expenses_repository.dart';
import '../data/groups_repository.dart';
import '../domain/group_expense_model.dart';
import '../domain/group_model.dart';
import '../../../core/utils/recurring_engine.dart';
import '../../notifications/data/notifications_repository.dart';

class AddGroupExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? editExpenseId;

  const AddGroupExpenseScreen({
    super.key,
    required this.groupId,
    this.editExpenseId,
  });

  @override
  ConsumerState<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends ConsumerState<AddGroupExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final Map<String, TextEditingController> _splitControllers = {};
  
  String? _selectedCategoryId;
  String? _selectedPayerUid;
  String _selectedSplitType = 'equal'; // 'equal' | 'custom' | 'percentage'
  
  // Splits State
  List<String> _selectedMemberUids = []; // For Equal
  final Map<String, double> _customAmounts = {}; // For Custom
  final Map<String, double> _percentages = {}; // For Percent
  List<GroupExpenseItemModel> _itemizedItems = []; // For Itemized
  
  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool _isRecurring = false;
  String _recurrenceInterval = 'weekly';
  String? _receiptUrl;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    for (final controller in _splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setupControllers(List<String> members) {
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    
    // Set default payer to current user if not set
    if (_selectedPayerUid == null && currentUid != null && members.contains(currentUid)) {
      _selectedPayerUid = currentUid;
    } else if (_selectedPayerUid == null && members.isNotEmpty) {
      _selectedPayerUid = members.first;
    }

    // Set default equal selected list to all members on first load
    if (_selectedMemberUids.isEmpty && !_initialized) {
      _selectedMemberUids = List.from(members);
    }

    for (final uid in members) {
      if (!_splitControllers.containsKey(uid)) {
        final controller = TextEditingController();
        _splitControllers[uid] = controller;
        
        // Listen and update state maps
        controller.addListener(() {
          final text = controller.text.trim();
          final val = double.tryParse(text) ?? 0.0;
          setState(() {
            if (_selectedSplitType == 'custom') {
              _customAmounts[uid] = val;
            } else if (_selectedSplitType == 'percentage') {
              _percentages[uid] = val;
            }
          });
        });
      }
    }
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
                        'Bill photo saved with group expense',
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

  void _initializeFields(GroupExpenseModel expense, List<String> members) {
    if (_initialized) return;
    _amountController.text = expense.amount.toStringAsFixed(2);
    _descriptionController.text = expense.description;
    _selectedCategoryId = expense.category;
    _selectedPayerUid = expense.payerUid;
    _selectedSplitType = expense.splitType;
    _isRecurring = expense.isRecurringTemplate;
    _recurrenceInterval = expense.recurrenceInterval ?? 'weekly';
    _receiptUrl = expense.receiptUrl;
    
    if (expense.splitType == 'equal') {
      _selectedMemberUids = expense.splits.keys.toList();
    } else if (expense.splitType == 'itemized') {
      _itemizedItems = List<GroupExpenseItemModel>.from(expense.items ?? []);
    } else if (expense.splitType == 'custom') {
      expense.splits.forEach((uid, val) {
        _customAmounts[uid] = val;
        if (_splitControllers.containsKey(uid)) {
          _splitControllers[uid]!.text = val.toStringAsFixed(2);
        }
      });
    } else if (expense.splitType == 'percentage') {
      expense.splits.forEach((uid, val) {
        final double pct = expense.amount > 0 ? (val / expense.amount) * 100 : 0.0;
        final roundedPct = double.parse(pct.toStringAsFixed(1));
        _percentages[uid] = roundedPct;
        if (_splitControllers.containsKey(uid)) {
          _splitControllers[uid]!.text = roundedPct.toString();
        }
      });
    }
    
    _initialized = true;
  }

  Map<String, double> _calculateFinalSplits(double totalAmount, String payerUid) {
    if (_selectedSplitType == 'equal') {
      if (_selectedMemberUids.isEmpty) return {};
      int totalCents = (totalAmount * 100).round();
      int count = _selectedMemberUids.length;
      int baseCents = totalCents ~/ count;
      int remainderCents = totalCents % count;
      
      Map<String, int> splitsCents = {};
      for (final uid in _selectedMemberUids) {
        splitsCents[uid] = baseCents;
      }
      
      if (_selectedMemberUids.contains(payerUid)) {
        splitsCents[payerUid] = splitsCents[payerUid]! + remainderCents;
      } else {
        splitsCents[payerUid] = (splitsCents[payerUid] ?? 0) + remainderCents;
      }
      
      Map<String, double> splits = {};
      splitsCents.forEach((uid, cents) {
        if (cents > 0) {
          splits[uid] = cents / 100.0;
        }
      });
      return splits;
    } else if (_selectedSplitType == 'itemized') {
      final Map<String, double> splits = {
        for (var uid in _splitControllers.keys) uid: 0.0,
      };

      for (final item in _itemizedItems) {
        if (item.memberUids.isEmpty) continue;
        int itemCents = (item.amount * 100).round();
        int count = item.memberUids.length;
        int baseCents = itemCents ~/ count;
        int remainderCents = itemCents % count;

        for (final uid in item.memberUids) {
          splits[uid] = (splits[uid] ?? 0.0) + (baseCents / 100.0);
        }

        if (remainderCents > 0) {
          final String targetUid = item.memberUids.contains(payerUid) ? payerUid : item.memberUids.first;
          splits[targetUid] = (splits[targetUid] ?? 0.0) + (remainderCents / 100.0);
        }
      }

      splits.forEach((uid, val) {
        splits[uid] = double.parse(val.toStringAsFixed(2));
      });

      return splits;
    } else if (_selectedSplitType == 'custom') {
      Map<String, double> splits = {};
      _customAmounts.forEach((uid, amt) {
        if (amt > 0) {
          splits[uid] = amt;
        }
      });
      return splits;
    } else {
      // Percentage
      int totalCents = (totalAmount * 100).round();
      Map<String, int> splitsCents = {};
      int runningSum = 0;
      
      _percentages.forEach((uid, pct) {
        if (pct > 0) {
          int cents = ((pct / 100.0) * totalCents).round();
          splitsCents[uid] = cents;
          runningSum += cents;
        }
      });
      
      int remainderCents = totalCents - runningSum;
      if (remainderCents != 0) {
        splitsCents[payerUid] = (splitsCents[payerUid] ?? 0) + remainderCents;
      }
      
      Map<String, double> splits = {};
      splitsCents.forEach((uid, cents) {
        if (cents > 0) {
          splits[uid] = cents / 100.0;
        }
      });
      return splits;
    }
  }

  bool _validateSplits(double totalAmount, String? payerUid) {
    if (payerUid == null) {
      _errorMessage = 'Please select a payer';
      return false;
    }
    if (_selectedSplitType == 'equal') {
      if (_selectedMemberUids.isEmpty) {
        _errorMessage = 'At least one member must be selected for equal split';
        return false;
      }
    } else if (_selectedSplitType == 'custom') {
      double sum = 0.0;
      _customAmounts.forEach((_, val) => sum += val);
      // Compare in cents to avoid double inaccuracies
      if ((sum * 100).round() != (totalAmount * 100).round()) {
        _errorMessage = 'Total of custom splits (₹${sum.toStringAsFixed(2)}) must equal total amount (₹${totalAmount.toStringAsFixed(2)})';
        return false;
      }
    } else if (_selectedSplitType == 'percentage') {
      double sum = 0.0;
      _percentages.forEach((_, val) => sum += val);
      if ((sum * 10).round() != 1000) { // 100.0 %
        _errorMessage = 'Total percentage split (${sum.toStringAsFixed(1)}%) must equal 100%';
        return false;
      }
    }
    return true;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryId == null) {
      setState(() {
        _errorMessage = 'Please select a category';
      });
      return;
    }

    double totalAmount = 0.0;
    if (_selectedSplitType == 'itemized') {
      totalAmount = _itemizedItems.fold(0.0, (sum, item) => sum + item.amount);
      if (_itemizedItems.isEmpty) {
        setState(() {
          _errorMessage = 'At least one item must be added for itemized split';
        });
        return;
      }
    } else {
      final double? parsed = double.tryParse(_amountController.text.trim());
      if (parsed == null || parsed <= 0) {
        setState(() {
          _errorMessage = 'Please enter a valid amount greater than 0';
        });
        return;
      }
      totalAmount = parsed;
    }

    if (!_validateSplits(totalAmount, _selectedPayerUid)) {
      setState(() {});
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final splitsMap = _calculateFinalSplits(totalAmount, _selectedPayerUid!);
      
      final expense = GroupExpenseModel(
        expenseId: widget.editExpenseId ?? const Uuid().v4(),
        payerUid: _selectedPayerUid!,
        amount: totalAmount,
        category: _selectedCategoryId!,
        description: _descriptionController.text.trim(),
        splitType: _selectedSplitType,
        splits: splitsMap,
        createdAt: DateTime.now(),
        isDeleted: false,
        receiptUrl: _receiptUrl,
        isRecurringTemplate: _isRecurring,
        recurrenceInterval: _isRecurring ? _recurrenceInterval : null,
        lastGeneratedDate: widget.editExpenseId != null ? null : null,
        isCancelled: false,
        items: _selectedSplitType == 'itemized' ? _itemizedItems : null,
      );

      if (widget.editExpenseId != null) {
        await ref.read(groupExpensesRepositoryProvider).updateGroupExpense(widget.groupId, expense);
      } else {
        await ref.read(groupExpensesRepositoryProvider).addGroupExpense(widget.groupId, expense);

        final group = ref.read(groupDetailsStreamProvider(widget.groupId)).value;
        if (group != null) {
          await ref.read(notificationsRepositoryProvider).sendExpenseAdded(
            recipientUids: group.members,
            groupId: widget.groupId,
            groupName: group.name,
            description: expense.description.isNotEmpty ? expense.description : 'Group Expense',
            amount: expense.amount,
          );
        }
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
    final groupAsync = ref.watch(groupDetailsStreamProvider(widget.groupId));
    final categoriesAsync = ref.watch(userCategoriesProvider);
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.editExpenseId != null ? 'EDIT EXPENSE' : 'ADD EXPENSE',
          style: AppTheme.monoStyle.copyWith(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 15,
          ),
        ),
        centerTitle: true,
        actions: [
          groupAsync.when(
            data: (group) => Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 20.0),
              child: Text(
                group?.name.toUpperCase() ?? '',
                style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
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
        child: groupAsync.when(
          data: (group) {
            if (group == null) {
              return const Center(child: Text('Group not found', style: TextStyle(color: Colors.red)));
            }
            
            _setupControllers(group.members);
            
            // If editing, wait for expenses stream to populate state
            if (widget.editExpenseId != null && !_initialized) {
              final expensesAsync = ref.watch(groupExpensesStreamProvider(widget.groupId));
              return expensesAsync.when(
                data: (expenses) {
                  final exp = expenses.firstWhere((e) => e.expenseId == widget.editExpenseId);
                  _initializeFields(exp, group.members);
                  return categoriesAsync.when(
                    data: (categories) => _buildForm(group, categories, currentUid),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              );
            }

            return categoriesAsync.when(
              data: (categories) => _buildForm(group, categories, currentUid),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  Widget _buildForm(GroupModel group, List<CategoryModel> categories, String currentUid) {
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    double totalAmount = 0.0;
    if (_selectedSplitType == 'itemized') {
      totalAmount = _itemizedItems.fold(0.0, (sum, item) => sum + item.amount);
    } else {
      totalAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
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

                    // Description Input Field
                    Text(
                      'DESCRIPTION',
                      style: AppTheme.monoSecondary.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                      cursorColor: AppTheme.accent,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Description is required';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        hintText: 'Dinner at Brittos',
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
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

                    // Amount Input Field (Mono styled)
                    if (_selectedSplitType != 'itemized') ...[
                      Text(
                        'AMOUNT',
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
                        onChanged: (val) {
                          setState(() {}); // Recalculate dynamic splits
                        },
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
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Receipt Attachment Section
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

                    // Category Selector
                    Text(
                      'CATEGORY',
                      style: AppTheme.monoSecondary.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategoryId == category.id;
                          final color = category.color;
                          
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategoryId = category.id;
                              });
                            },
                            child: Container(
                              width: 80,
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
                                    category.icon,
                                    color: isSelected ? color : AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    category.name.toUpperCase(),
                                    style: AppTheme.monoStyle.copyWith(
                                      fontSize: 9,
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
                    ),
                    const SizedBox(height: 24),

                    // Paid By Selection
                    Text(
                      'PAID BY',
                      style: AppTheme.monoSecondary.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPayerUid,
                          dropdownColor: AppTheme.surfaceCard,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.accent),
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                          isExpanded: true,
                          items: group.members.map((uid) {
                            return DropdownMenuItem<String>(
                              value: uid,
                              child: MemberNameText(uid: uid, currentUid: currentUid),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedPayerUid = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Split Selector Tabs
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          _buildSplitTab('equal', 'Equal'),
                          _buildSplitTab('custom', 'Custom'),
                          _buildSplitTab('percentage', 'Percent'),
                          _buildSplitTab('itemized', 'Itemized'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Rounding Info Banner (Equal split with rounding remainder)
                    if (_selectedSplitType == 'equal' && totalAmount > 0) ...[
                      _buildRoundingBanner(totalAmount),
                      const SizedBox(height: 16),
                    ],

                    if (_selectedSplitType == 'itemized') ...[
                      _buildItemizedListBuilder(group.members, currentUid),
                    ] else ...[
                      // Split Members List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MEMBER',
                            style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                          Text(
                            _selectedSplitType == 'custom'
                                ? 'AMOUNT (₹)'
                                : _selectedSplitType == 'percentage'
                                    ? 'PERCENT (%)'
                                    : 'SHARE',
                            style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Split Members List Cards
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: group.members.length,
                          separatorBuilder: (context, index) => Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                          itemBuilder: (context, index) {
                            final uid = group.members[index];
                            return _buildSplitMemberRow(uid, currentUid, totalAmount);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _showAddMemberDialog(context, ref, group),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_alt_1_outlined, color: AppTheme.accent, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'ADD MEMBER TO GROUP',
                                style: AppTheme.monoStyle.copyWith(
                                  color: AppTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Footer Save button
        InkWell(
          onTap: _isLoading ? null : _handleSave,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              color: AppTheme.accent,
            ),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      'SAVE EXPENSE',
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
      ],
    );
  }

  Widget _buildSplitTab(String type, String label) {
    final isSelected = _selectedSplitType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSplitType = type;
            _errorMessage = null; // Clear previous validation error
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent : Colors.transparent,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTheme.monoStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundingBanner(double totalAmount) {
    int totalCents = (totalAmount * 100).round();
    int count = _selectedMemberUids.length;
    if (count == 0) return const SizedBox();
    
    int remainderCents = totalCents % count;
    if (remainderCents == 0) return const SizedBox();

    final remainderAmt = remainderCents / 100.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.05),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'A remainder of ₹${remainderAmt.toStringAsFixed(2)} is added to the payer\'s share due to rounding.',
              style: AppTheme.monoSecondary.copyWith(fontSize: 10, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitMemberRow(String uid, String currentUid, double totalAmount) {
    if (_selectedSplitType == 'equal') {
      final isSelected = _selectedMemberUids.contains(uid);
      
      // Calculate share
      double share = 0.0;
      if (isSelected && totalAmount > 0) {
        final Map<String, double> tempSplits = _calculateFinalSplits(totalAmount, _selectedPayerUid ?? currentUid);
        share = tempSplits[uid] ?? 0.0;
      }

      return CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppTheme.accent,
        checkColor: Colors.black,
        title: MemberNameText(
          uid: uid,
          currentUid: currentUid,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              if (!_selectedMemberUids.contains(uid)) {
                _selectedMemberUids.add(uid);
              }
            } else {
              _selectedMemberUids.remove(uid);
            }
          });
        },
        secondary: Text(
          '₹${share.toStringAsFixed(2)}',
          style: AppTheme.monoStyle.copyWith(
            fontSize: 13,
            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      );
    } else if (_selectedSplitType == 'custom') {
      final controller = _splitControllers[uid];
      
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15))),
          child: const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
        ),
        title: MemberNameText(
          uid: uid,
          currentUid: currentUid,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        trailing: SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            style: AppTheme.monoStyle.copyWith(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
              prefixText: '₹',
              prefixStyle: const TextStyle(color: AppTheme.accent),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent, width: 1.5)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3))),
            ),
          ),
        ),
      );
    } else {
      // Percentage
      final controller = _splitControllers[uid];
      final pct = _percentages[uid] ?? 0.0;
      final double share = totalAmount > 0 ? (pct / 100.0) * totalAmount : 0.0;

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15))),
          child: const Icon(Icons.percent, size: 16, color: AppTheme.textSecondary),
        ),
        title: MemberNameText(
          uid: uid,
          currentUid: currentUid,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Calculated: ₹${share.toStringAsFixed(2)}',
            style: AppTheme.monoSecondary.copyWith(fontSize: 10),
          ),
        ),
        trailing: SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            style: AppTheme.monoStyle.copyWith(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
              suffixText: '%',
              suffixStyle: const TextStyle(color: AppTheme.accent),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent, width: 1.5)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3))),
            ),
          ),
        ),
      );
    }
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref, GroupModel group) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Consumer(
            builder: (context, ref, child) {
              final friendsAsync = ref.watch(friendsStreamProvider);
              return friendsAsync.when(
                data: (friends) {
                  final eligibleFriends = friends
                      .where((f) => f.status == 'accepted' && !group.members.contains(f.uid))
                      .toList();

                  return Container(
                    padding: const EdgeInsets.all(24),
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ADD MEMBER',
                          style: AppTheme.monoStyle.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select an accepted friend to add to this group.',
                          style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                        ),
                        const SizedBox(height: 16),
                        
                        // Add New Friend By Code Action Button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _showAddNewFriendDialog(context, ref);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                '+ CONNECT NEW FRIEND',
                                style: AppTheme.monoStyle.copyWith(
                                  color: AppTheme.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (eligibleFriends.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                'No other accepted friends.',
                                style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: eligibleFriends.length,
                              separatorBuilder: (context, index) => Divider(
                                color: AppTheme.textSecondary.withValues(alpha: 0.15),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final friend = eligibleFriends[index];
                                final detailsAsync = ref.watch(friendDetailsProvider(friend.uid));

                                return detailsAsync.when(
                                  data: (details) {
                                    final name = details?['displayName'] ?? 'User';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        name,
                                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent, size: 20),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          try {
                                            await ref.read(groupsRepositoryProvider).sendGroupInvite(group.groupId, friend.uid);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Group invitation sent to $name!'),
                                                  backgroundColor: AppTheme.accent,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: AppTheme.semanticNegative,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  loading: () => const ListTile(title: Text('Loading...')),
                                  error: (e, s) => const ListTile(title: Text('Error')),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CLOSE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading friends: $err', style: const TextStyle(color: Colors.red)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showAddNewFriendDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String? dialogError;
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text(
                'CONNECT NEW FRIEND',
                style: AppTheme.monoStyle.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogError != null) ...[
                    Text(
                      dialogError!,
                      style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Enter their 6-character app code:',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                     controller: controller,
                     autofocus: true,
                     style: AppTheme.monoStyle.copyWith(color: AppTheme.textPrimary, fontSize: 13),
                     decoration: const InputDecoration(
                       hintText: 'A1B2C3',
                       focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
                       enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary)),
                     ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ),
                TextButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                           final code = controller.text.trim();
                           if (code.isEmpty) return;

                           setState(() {
                             isAdding = true;
                             dialogError = null;
                           });

                           try {
                             await ref.read(friendsRepositoryProvider).addFriendByCode(code);
                             if (context.mounted) {
                               Navigator.pop(context);
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(
                                   content: Text('Friend request sent!'),
                                   backgroundColor: AppTheme.accent,
                                 ),
                               );
                             }
                           } catch (e) {
                             setState(() {
                               dialogError = e.toString().replaceFirst('Exception: ', '');
                               isAdding = false;
                             });
                           }
                         },
                  child: isAdding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
                        )
                      : const Text('CONNECT', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showAddEditItemDialog({int? index}) {
    final isEditing = index != null;
    final item = isEditing ? _itemizedItems[index] : null;

    final nameController = TextEditingController(text: item?.name ?? '');
    final amountController = TextEditingController(text: item?.amount.toString() ?? '');
    List<String> selectedUids = isEditing ? List.from(item!.memberUids) : List.from(_splitControllers.keys);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceBase,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text(
                isEditing ? 'EDIT ITEM' : 'ADD ITEM',
                style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item Name
                    Text(
                      'ITEM NAME',
                      style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      cursorColor: AppTheme.accent,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        hintText: 'Kingfisher Ultra (6x)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Item Amount
                    Text(
                      'AMOUNT (₹)',
                      style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      cursorColor: AppTheme.accent,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        hintText: '1200.00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Split Between Checklist
                    Text(
                      'SPLIT BETWEEN',
                      style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 12),
                    
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _splitControllers.keys.length,
                        itemBuilder: (context, idx) {
                          final uid = _splitControllers.keys.elementAt(idx);
                          final isSelected = selectedUids.contains(uid);

                          return CheckboxListTile(
                            value: isSelected,
                            title: Consumer(
                              builder: (context, ref, child) {
                                final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
                                return MemberNameText(uid: uid, currentUid: currentUid ?? '');
                              },
                            ),
                            activeColor: AppTheme.accent,
                            checkColor: Colors.black,
                            checkboxShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedUids.add(uid);
                                } else {
                                  selectedUids.remove(uid);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCEL', style: AppTheme.monoSecondary.copyWith(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (name.isEmpty || amt <= 0 || selectedUids.isEmpty) {
                      return;
                    }

                    setState(() {
                      final newItem = GroupExpenseItemModel(
                        name: name,
                        amount: amt,
                        memberUids: selectedUids,
                      );
                      if (isEditing) {
                        _itemizedItems[index] = newItem;
                      } else {
                        _itemizedItems.add(newItem);
                      }
                    });

                    Navigator.pop(context);
                  },
                  child: Text(
                    isEditing ? 'SAVE' : 'ADD',
                    style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildItemizedListBuilder(List<String> members, String? currentUid) {
    final double runningTotal = _itemizedItems.fold(0.0, (sum, item) => sum + item.amount);
    final calculatedSplits = _calculateFinalSplits(runningTotal, _selectedPayerUid ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ITEMIZED SPLIT',
              style: AppTheme.monoSecondary.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Items list cards
        if (_itemizedItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Text(
                'No items added yet.',
                style: AppTheme.monoSecondary.copyWith(fontSize: 11),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _itemizedItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _itemizedItems[index];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard.withValues(alpha: 0.2),
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '₹${item.amount.toStringAsFixed(2)}',
                              style: AppTheme.monoStyle.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                              onPressed: () => _showAddEditItemDialog(index: index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.semanticNegative, size: 18),
                              onPressed: () {
                                setState(() {
                                  _itemizedItems.removeAt(index);
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Member initials row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members.map((uid) {
                        final isIncluded = item.memberUids.contains(uid);
                        return MemberInitialAvatar(
                          uid: uid,
                          isActive: isIncluded,
                          onTap: () {
                            setState(() {
                              final List<String> updatedUids = List.from(item.memberUids);
                              if (isIncluded) {
                                updatedUids.remove(uid);
                              } else {
                                updatedUids.add(uid);
                              }
                              _itemizedItems[index] = GroupExpenseItemModel(
                                name: item.name,
                                amount: item.amount,
                                memberUids: updatedUids,
                              );
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 16),

        // Add Item Button
        InkWell(
          onTap: () => _showAddEditItemDialog(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.8)),
              color: AppTheme.accent.withValues(alpha: 0.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: AppTheme.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'ADD ITEM',
                  style: AppTheme.monoStyle.copyWith(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // CALCULATED TOTALS CARD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
            color: AppTheme.surfaceCard.withValues(alpha: 0.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CALCULATED TOTALS',
                style: AppTheme.monoSecondary.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 16),
              // Members calculated list
              ...members.map((uid) {
                final double share = calculatedSplits[uid] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MemberNameText(uid: uid, currentUid: currentUid ?? ''),
                      Text(
                        '₹${share.toStringAsFixed(2)}',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(color: AppTheme.textSecondary, height: 24, thickness: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Running Total',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹${runningTotal.toStringAsFixed(2)}',
                    style: AppTheme.monoStyle.copyWith(
                      color: AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Receipt Total',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Text(
                        '₹${runningTotal.toStringAsFixed(2)}',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 16),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MemberInitialAvatar extends ConsumerWidget {
  final String uid;
  final bool isActive;
  final VoidCallback onTap;

  const MemberInitialAvatar({
    super.key,
    required this.uid,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    String name = 'User';
    if (currentUser != null && currentUser.uid == uid) {
      name = currentUser.displayName ?? 'You';
    } else {
      final details = ref.watch(friendDetailsProvider(uid)).value;
      name = details?['displayName'] ?? 'User';
    }

    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent : Colors.transparent,
          border: Border.all(
            color: isActive ? AppTheme.accent : AppTheme.textSecondary.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              color: isActive ? Colors.black : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class MemberNameText extends ConsumerWidget {
  final String uid;
  final String currentUid;
  final TextStyle? style;

  const MemberNameText({
    super.key,
    required this.uid,
    required this.currentUid,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uid == currentUid) {
      return Text('You', style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final detailsAsync = ref.watch(friendDetailsProvider(uid));
    return detailsAsync.when(
      data: (details) => Text(details?['displayName'] ?? 'User', style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      loading: () => Text('Loading...', style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      error: (e, s) => Text('User', style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
