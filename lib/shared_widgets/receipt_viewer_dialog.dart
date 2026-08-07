import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final String receiptUrl;
  final String description;
  final double amount;
  final String dateStr;

  const ReceiptViewerDialog({
    super.key,
    required this.receiptUrl,
    required this.description,
    required this.amount,
    required this.dateStr,
  });

  static void show(
    BuildContext context, {
    required String receiptUrl,
    required String description,
    required double amount,
    required String dateStr,
  }) {
    showDialog(
      context: context,
      builder: (context) => ReceiptViewerDialog(
        receiptUrl: receiptUrl,
        description: description,
        amount: amount,
        dateStr: dateStr,
      ),
    );
  }

  Widget _buildImageWidget() {
    final clean = receiptUrl.trim();

    if (clean.startsWith('data:image')) {
      final base64Str = clean.split(',').last;
      final bytes = base64Decode(base64Str);
      return Image.memory(bytes, fit: BoxFit.contain);
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: clean,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppTheme.semanticNegative, size: 48),
        ),
      );
    } else if (File(clean).existsSync()) {
      return Image.file(File(clean), fit: BoxFit.contain);
    } else {
      // Try decoding raw base64 if not prefixed
      try {
        final bytes = base64Decode(clean);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        return const Center(
          child: Icon(Icons.receipt_long_outlined, color: AppTheme.accent, size: 64),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceBase,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.accent, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.surfaceCard,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ATTACHED RECEIPT',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textPrimary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),

            // Expense Metadata
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rs. ${amount.toStringAsFixed(2)}',
                    style: AppTheme.monoStyle.copyWith(
                      color: AppTheme.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),

            // Image Container with Zoom support
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              width: double.infinity,
              color: Colors.black,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildImageWidget(),
                  ),
                ),
              ),
            ),

            // Bottom Note
            Container(
              padding: const EdgeInsets.all(12),
              color: AppTheme.surfaceCard.withValues(alpha: 0.3),
              width: double.infinity,
              child: Text(
                'Pinch or scroll to zoom in/out on the bill document.',
                style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
