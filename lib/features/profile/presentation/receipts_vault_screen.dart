import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/data/group_expenses_repository.dart';
import '../../../shared_widgets/receipt_viewer_dialog.dart';

class VaultReceiptItem {
  final String id;
  final String description;
  final double amount;
  final DateTime createdAt;
  final String receiptUrl;
  final String sourceLabel;

  VaultReceiptItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.createdAt,
    required this.receiptUrl,
    required this.sourceLabel,
  });
}

class ReceiptsVaultScreen extends ConsumerWidget {
  const ReceiptsVaultScreen({super.key});

  Widget _buildThumbnail(String receiptUrl) {
    final clean = receiptUrl.trim();
    if (clean.startsWith('data:image')) {
      try {
        final bytes = base64Decode(clean.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: clean,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, url, error) => const Icon(Icons.receipt_long, color: AppTheme.accent),
      );
    } else if (File(clean).existsSync()) {
      return Image.file(File(clean), fit: BoxFit.cover);
    }
    return const Center(child: Icon(Icons.receipt_long, color: AppTheme.accent, size: 28));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalExpensesAsync = ref.watch(personalExpensesProvider);
    final groupsAsync = ref.watch(groupsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'RECEIPTS VAULT',
          style: AppTheme.monoStyle.copyWith(
            color: AppTheme.accent,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
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
        child: personalExpensesAsync.when(
          data: (personalExpenses) {
            final List<VaultReceiptItem> allVaultReceipts = [];

            // 1. Add Personal Expenses Receipts
            for (final exp in personalExpenses) {
              if (!exp.isRecurringTemplate && exp.receiptUrl != null && exp.receiptUrl!.isNotEmpty) {
                allVaultReceipts.add(
                  VaultReceiptItem(
                    id: exp.id,
                    description: exp.description.isNotEmpty ? exp.description : 'Personal Expense',
                    amount: exp.amount,
                    createdAt: exp.createdAt,
                    receiptUrl: exp.receiptUrl!,
                    sourceLabel: 'PERSONAL',
                  ),
                );
              }
            }

            // 2. Add Group Expenses Receipts
            final groups = groupsAsync.value ?? [];
            for (final group in groups) {
              final groupExpensesAsync = ref.watch(groupExpensesStreamProvider(group.groupId));
              final groupExpenses = groupExpensesAsync.value ?? [];
              for (final gExp in groupExpenses) {
                if (!gExp.isDeleted && !gExp.isRecurringTemplate && gExp.receiptUrl != null && gExp.receiptUrl!.isNotEmpty) {
                  allVaultReceipts.add(
                    VaultReceiptItem(
                      id: gExp.expenseId,
                      description: gExp.description.isNotEmpty ? gExp.description : 'Group Expense',
                      amount: gExp.amount,
                      createdAt: gExp.createdAt,
                      receiptUrl: gExp.receiptUrl!,
                      sourceLabel: 'GROUP: ${group.name.toUpperCase()}',
                    ),
                  );
                }
              }
            }

            // Sort newest first
            allVaultReceipts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (allVaultReceipts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceCard,
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.accent),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'NO RECEIPTS FOUND',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Attach camera or gallery bill photos when creating personal or group expenses to store them in your vault.',
                        style: AppTheme.monoSecondary.copyWith(fontSize: 12, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vault Counter Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_special_outlined, color: AppTheme.accent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'STORED BILL RECEIPTS',
                              style: AppTheme.monoStyle.copyWith(
                                color: AppTheme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          color: AppTheme.accent,
                          child: Text(
                            '${allVaultReceipts.length} TOTAL',
                            style: AppTheme.monoStyle.copyWith(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Receipts Grid List
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: allVaultReceipts.length,
                      itemBuilder: (context, index) {
                        final item = allVaultReceipts[index];
                        final dateStr = DateFormat('dd MMM yyyy').format(item.createdAt).toUpperCase();

                        return InkWell(
                          onTap: () {
                            ReceiptViewerDialog.show(
                              context,
                              receiptUrl: item.receiptUrl,
                              description: item.description,
                              amount: item.amount,
                              dateStr: dateStr,
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard.withValues(alpha: 0.4),
                              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Receipt Thumbnail Box
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.black,
                                    child: _buildThumbnail(item.receiptUrl),
                                  ),
                                ),

                                // Details Box
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Source Badge
                                      Text(
                                        item.sourceLabel,
                                        style: AppTheme.monoStyle.copyWith(
                                          color: AppTheme.accent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // Description
                                      Text(
                                        item.description,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // Amount & Date
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹${item.amount.toStringAsFixed(2)}',
                                            style: AppTheme.monoStyle.copyWith(
                                              color: AppTheme.textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            dateStr,
                                            style: AppTheme.monoSecondary.copyWith(fontSize: 8),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading receipts: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }
}
