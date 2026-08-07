import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../../friends/data/friends_repository.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../../notifications/data/notifications_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  File? _localImageFile;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _localImageFile = File(picked.path);
      });

      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null) {
        final photoPath = picked.path;
        await user.updatePhotoURL(photoPath);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'photoUrl': photoPath,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: AppTheme.semanticNegative,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined, color: AppTheme.accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'UPDATE PROFILE PHOTO',
                      style: AppTheme.monoStyle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.textPrimary),
                  title: const Text('Take Photo', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppTheme.textPrimary),
                  title: const Text('Choose from Gallery', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStandardPersonIcon(String initials) {
    return Container(
      width: 88,
      height: 88,
      color: AppTheme.surfaceCard,
      child: Center(
        child: Icon(
          Icons.person,
          size: 48,
          color: AppTheme.accent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final displayName = user?.displayName ?? 'SplitMate User';
    final email = user?.email ?? 'user@splitmate.com';

    // Watch real dynamic stats
    final groupsAsync = ref.watch(groupsStreamProvider);
    final friendsAsync = ref.watch(friendsStreamProvider);
    final expensesAsync = ref.watch(personalExpensesProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    final groupsCount = groupsAsync.value?.length ?? 0;
    final friendsCount = friendsAsync.value?.length ?? 0;
    final trackedCount = expensesAsync.value?.where((e) => !e.isRecurringTemplate).length ?? 0;
    
    // Generate initials for fallback avatar
    final initials = displayName.isNotEmpty
        ? displayName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'SM';

    final photoUrl = user?.photoURL;
    Widget avatarWidget;
    if (_localImageFile != null) {
      avatarWidget = Image.file(_localImageFile!, fit: BoxFit.cover, width: 88, height: 88);
    } else if (photoUrl != null && photoUrl.isNotEmpty && (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))) {
      avatarWidget = CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        width: 88,
        height: 88,
        errorWidget: (context, url, error) => _buildStandardPersonIcon(initials),
      );
    } else if (photoUrl != null && photoUrl.isNotEmpty && File(photoUrl).existsSync()) {
      avatarWidget = Image.file(File(photoUrl), fit: BoxFit.cover, width: 88, height: 88);
    } else {
      avatarWidget = _buildStandardPersonIcon(initials);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              color: AppTheme.surfaceCard,
            ),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(
          'SplitMate',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
        ),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Profile Photo & Edit Badge
                Center(
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accent, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(48),
                          child: avatarWidget,
                        ),
                      ),
                      // Floating Edit Badge
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: InkWell(
                          onTap: _showImageSourceSheet,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Colors.black,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // User Details
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Stats Row (Dynamic real-time numbers)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(label: 'GROUPS', value: '$groupsCount'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(label: 'FRIENDS', value: '$friendsCount'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        label: 'TRACKED',
                        value: '$trackedCount',
                        valueColor: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Account Settings Card
                _buildSectionCard(
                  title: 'ACCOUNT SETTINGS',
                  children: [
                    _buildSettingRow(
                      icon: Icons.person_outline,
                      title: 'Personal Information',
                      subtitle: 'Name, email, and primary currency',
                      onTap: () => context.push('/profile/personal-info'),
                    ),
                    _buildSettingRow(
                      icon: Icons.notifications_none_outlined,
                      title: 'Notifications',
                      subtitle: unreadCount > 0
                          ? '$unreadCount unread alert${unreadCount > 1 ? 's' : ''}'
                          : 'Manage transaction and group alerts',
                      trailing: unreadCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              color: AppTheme.accent,
                              child: Text(
                                '$unreadCount NEW',
                                style: AppTheme.monoStyle.copyWith(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Preferences Card
                _buildSectionCard(
                  title: 'PREFERENCES',
                  children: [
                    // Receipts Vault Row
                    _buildSettingRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'Receipts Vault',
                      subtitle: 'View and search all uploaded bill receipts',
                      onTap: () => context.push('/profile/receipts'),
                    ),
                    // Recurring Expenses Row
                    _buildSettingRow(
                      icon: Icons.repeat,
                      title: 'Recurring Expenses',
                      subtitle: 'Manage personal & group automated templates',
                      onTap: () => context.push('/recurring-expenses'),
                    ),
                    // Manage Categories Row
                    _buildSettingRow(
                      icon: Icons.category_outlined,
                      title: 'Manage Categories',
                      subtitle: 'Add, edit, or delete expense tags',
                      onTap: () => context.push('/categories'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Logout Card
                _buildSectionCard(
                  children: [
                    _buildSettingRow(
                      icon: Icons.logout_outlined,
                      iconColor: AppTheme.semanticNegative,
                      title: 'Logout',
                      titleColor: AppTheme.semanticNegative,
                      onTap: () async {
                        await ref.read(authRepositoryProvider).signOut();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    Color valueColor = AppTheme.textPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.2),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTheme.monoSecondary.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.monoStyle.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    String? title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                ),
              ),
              child: Text(
                title,
                style: AppTheme.monoSecondary.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            separatorBuilder: (context, index) => Divider(
              color: AppTheme.textSecondary.withValues(alpha: 0.15),
              height: 1.0,
              thickness: 1.0,
            ),
            itemBuilder: (context, index) => children[index],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    Color iconColor = AppTheme.accent,
    required String title,
    Color titleColor = AppTheme.textPrimary,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          border: Border.all(color: iconColor.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                subtitle,
                style: AppTheme.monoSecondary.copyWith(fontSize: 11),
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                  size: 20,
                )
              : null),
    );
  }
}
