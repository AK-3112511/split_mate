import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isSavingName = false;
  String _selectedCurrency = 'INR (₹)';

  final List<String> _currencies = [
    'INR (₹)',
    'USD (\$)',
    'EUR (€)',
    'GBP (£)',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isSavingName = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() {
            _isEditingName = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Display name updated successfully!'),
              backgroundColor: AppTheme.semanticPositive,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update name: $e'),
            backgroundColor: AppTheme.semanticNegative,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  Future<void> _updateCurrency(String newCurrency) async {
    setState(() {
      _selectedCurrency = newCurrency;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'primaryCurrency': newCurrency,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final uid = user?.uid ?? '';
    final email = user?.email ?? 'user@splitmate.com';
    final isVerified = user?.emailVerified ?? false;

    final userDocStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PERSONAL INFORMATION',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
            color: AppTheme.textSecondary.withValues(alpha: 0.15),
            height: 1.0,
            thickness: 1.0,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final appCode = (data['appCode'] as String?) ?? 'SM8899';
          final savedCurrency = (data['primaryCurrency'] as String?) ?? 'INR (₹)';
          final creationTime = user?.metadata.creationTime;
          final memberSinceStr = creationTime != null
              ? DateFormat('MMMM yyyy').format(creationTime)
              : 'August 2026';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IDENTITY & PREFERENCES',
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Container Box 1: Full Name & Email
                  _buildSectionContainer(
                    children: [
                      // Full Name Row
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'FULL NAME',
                                  style: AppTheme.monoSecondary.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                if (!_isEditingName)
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isEditingName = true;
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined, color: AppTheme.accent, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'EDIT',
                                          style: AppTheme.monoStyle.copyWith(
                                            color: AppTheme.accent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isEditingName)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nameController,
                                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                      decoration: const InputDecoration(
                                        filled: true,
                                        fillColor: AppTheme.surfaceCard,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: AppTheme.accent),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: AppTheme.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: _isSavingName
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.check, color: AppTheme.semanticPositive),
                                    onPressed: _isSavingName ? null : _saveDisplayName,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                                    onPressed: () {
                                      setState(() {
                                        _isEditingName = false;
                                        _nameController.text = user?.displayName ?? '';
                                      });
                                    },
                                  ),
                                ],
                              )
                            else
                              Text(
                                user?.displayName ?? 'Not Provided',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),

                      // Email Row
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMAIL ADDRESS',
                              style: AppTheme.monoSecondary.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    email,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isVerified ? AppTheme.semanticPositive : Colors.orange)
                                        .withValues(alpha: 0.15),
                                    border: Border.all(
                                      color: isVerified ? AppTheme.semanticPositive : Colors.orange,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isVerified ? Icons.check_circle : Icons.warning_amber_rounded,
                                        size: 12,
                                        color: isVerified ? AppTheme.semanticPositive : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isVerified ? 'VERIFIED' : 'UNVERIFIED',
                                        style: AppTheme.monoStyle.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isVerified ? AppTheme.semanticPositive : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'SPLITMATE CODES & CURRENCY',
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Container Box 2: Friend Code & Currency
                  _buildSectionContainer(
                    children: [
                      // App Friend Code Row
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MY FRIEND CONNECT CODE',
                                  style: AppTheme.monoSecondary.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  appCode,
                                  style: AppTheme.monoStyle.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                                side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
                                shape: const RoundedRectangleBorder(),
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: appCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Friend code copied to clipboard!'),
                                    backgroundColor: AppTheme.accent,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 14),
                              label: Text(
                                'COPY',
                                style: AppTheme.monoStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),

                      // Primary Currency Dropdown Row
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PRIMARY CURRENCY',
                                  style: AppTheme.monoSecondary.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Default symbol for reports',
                                  style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                            DropdownButton<String>(
                              value: _currencies.contains(savedCurrency) ? savedCurrency : _currencies.first,
                              dropdownColor: AppTheme.surfaceCard,
                              style: AppTheme.monoStyle.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              underline: Container(height: 1, color: AppTheme.accent),
                              items: _currencies.map((curr) {
                                return DropdownMenuItem<String>(
                                  value: curr,
                                  child: Text(curr),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  _updateCurrency(val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),

                      // Member Since Row
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MEMBER SINCE',
                              style: AppTheme.monoSecondary.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              memberSinceStr,
                              style: AppTheme.monoSecondary.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.2),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
