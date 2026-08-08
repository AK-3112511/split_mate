import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../friends/data/friends_repository.dart';
import '../../friends/domain/friend_model.dart';
import '../data/groups_repository.dart';
import '../domain/group_model.dart';
import '../domain/group_invite_model.dart';
import '../../../core/utils/settlement_algorithm.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/domain/notification_model.dart';

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  final _groupNameController = TextEditingController();
  final List<String> _selectedFriendUids = [];
  bool _isCreating = false;
  String? _modalError;

  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateGroupForm() {
    _groupNameController.clear();
    _selectedFriendUids.clear();
    _modalError = null;
    _isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CREATE GROUP LEDGER',
                      style: AppTheme.monoStyle.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_modalError != null) ...[
                      Text(
                        _modalError!,
                        style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Group Name Textfield
                    Text(
                      'GROUP NAME',
                      style: AppTheme.monoSecondary.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _groupNameController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                      cursorColor: AppTheme.accent,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        hintText: 'Goa Trip 2026',
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

                    // Members checklist section
                    Text(
                      'ADD MEMBERS',
                      style: AppTheme.monoSecondary.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Consumer(
                      builder: (context, ref, child) {
                        final friendsAsync = ref.watch(friendsStreamProvider);
                        return friendsAsync.when(
                          data: (friends) {
                            final acceptedFriends = friends.where((f) => f.status == 'accepted').toList();
                            if (acceptedFriends.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                                ),
                                child: Center(
                                  child: Text(
                                    'Connect with friends first to add them.',
                                    style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                                  ),
                                ),
                              );
                            }
                            return Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: acceptedFriends.length,
                                separatorBuilder: (context, index) => Divider(
                                  color: AppTheme.textSecondary.withValues(alpha: 0.15),
                                  height: 1,
                                ),
                                itemBuilder: (context, index) {
                                  final friend = acceptedFriends[index];
                                  final isSelected = _selectedFriendUids.contains(friend.uid);

                                  // Load friend details
                                  final detailsAsync = ref.watch(friendDetailsProvider(friend.uid));

                                  return detailsAsync.when(
                                    data: (details) {
                                      final originalName = details?['displayName'] ?? 'User';
                                      final name = (friend.nickname != null && friend.nickname!.isNotEmpty) ? friend.nickname! : originalName;
                                      final email = details?['email'] ?? 'Active...';
                                      
                                      return CheckboxListTile(
                                        value: isSelected,
                                        title: Text(
                                          name,
                                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          email,
                                          style: AppTheme.monoSecondary.copyWith(fontSize: 9),
                                        ),
                                        activeColor: AppTheme.accent,
                                        checkColor: Colors.black,
                                        checkboxShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                        onChanged: (val) {
                                          setModalState(() {
                                            if (val == true) {
                                              _selectedFriendUids.add(friend.uid);
                                            } else {
                                              _selectedFriendUids.remove(friend.uid);
                                            }
                                          });
                                        },
                                      );
                                    },
                                    loading: () => const ListTile(title: Text('Loading friend...')),
                                    error: (e, s) => ListTile(title: Text('Error: $e')),
                                  );
                                },
                              ),
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
                            ),
                          ),
                          error: (e, s) => Container(
                            padding: const EdgeInsets.all(16),
                            child: Text('Error loading friends: $e', style: const TextStyle(color: Colors.red, fontSize: 11)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit CTA button
                    InkWell(
                      onTap: _isCreating
                          ? null
                          : () async {
                              final name = _groupNameController.text.trim();
                              if (name.isEmpty) {
                                setModalState(() {
                                  _modalError = 'Group name is required';
                                });
                                  return;
                              }

                              setModalState(() {
                                _isCreating = true;
                                _modalError = null;
                              });

                              try {
                                await ref
                                    .read(groupsRepositoryProvider)
                                    .createGroup(name, _selectedFriendUids);
                                if (context.mounted) {
                                  Navigator.pop(context); // close bottom sheet
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Group created successfully'),
                                      backgroundColor: AppTheme.accent,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  _modalError = e.toString().replaceFirst('Exception: ', '');
                                  _isCreating = false;
                                });
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                        ),
                        child: Center(
                          child: _isCreating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : Text(
                                  'CREATE LEDGER',
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
              );
            },
          ),
        );
      },
    );
  }

  void _showJoinGroupByCodeDialog() {
    final codeController = TextEditingController();
    String? dialogError;
    bool isJoining = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_outlined, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'JOIN GROUP WITH CODE',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 20),
                  if (dialogError != null) ...[
                    Text(
                      dialogError!,
                      style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'GROUP CODE',
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                    cursorColor: AppTheme.accent,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceCard,
                      hintText: 'e.g. GRP987',
                      hintStyle: AppTheme.monoStyle.copyWith(
                        color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
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
                  InkWell(
                    onTap: isJoining
                        ? null
                        : () async {
                            final code = codeController.text.trim();
                            if (code.isEmpty) {
                              setSheetState(() => dialogError = 'Please enter a group code');
                              return;
                            }
                            setSheetState(() {
                              isJoining = true;
                              dialogError = null;
                            });

                            try {
                              await ref.read(groupsRepositoryProvider).joinGroupWithCode('', code);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Joined group successfully!'),
                                    backgroundColor: AppTheme.accent,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() {
                                dialogError = e.toString().replaceFirst('Exception: ', '');
                                isJoining = false;
                              });
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                      ),
                      child: Center(
                        child: isJoining
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text(
                                'JOIN GROUP',
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsStreamProvider);
    final friendsAsync = ref.watch(friendsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search groups...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Text(
                'SplitMate',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
              ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppTheme.textPrimary),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(unreadNotificationCountProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
                    onPressed: () => _showNotificationsSheet(context, ref),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.semanticNegative,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
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
        child: groupsAsync.when(
          data: (groups) {
            final filteredGroups = groups.where((g) {
              if (_searchQuery.trim().isEmpty) return true;
              return g.name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
            }).toList();
            return _buildBody(filteredGroups);
          },
          loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent))),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupForm,
        backgroundColor: AppTheme.accent,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildBody(List<GroupModel> groups) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Card: CREDITORS & DEBTORS Summary Card
            Consumer(
              builder: (context, ref, child) {
                final overviewAsync = ref.watch(globalSettlementOverviewProvider);

                return overviewAsync.when(
                  data: (data) {
                    final creditorCount = data['creditorGroupsCount'] as int;
                    final debtorCount = data['debtorGroupsCount'] as int;
                    final totalOwed = data['totalOwed'] as double;
                    final totalOwe = data['totalOwe'] as double;

                    final creditorLabel = creditorCount == 1 ? 'Group owes you' : 'Groups owe you';
                    final debtorLabel = debtorCount == 1 ? 'Group needs' : 'Groups need';

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                        color: AppTheme.surfaceCard.withValues(alpha: 0.2),
                      ),
                      child: Row(
                        children: [
                          // Left Column: Creditors
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CREDITORS',
                                    style: AppTheme.monoSecondary.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$creditorCount $creditorLabel',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+₹${totalOwed.toStringAsFixed(2)}',
                                    style: AppTheme.monoStyle.copyWith(
                                      color: AppTheme.semanticPositive,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Middle Vertical Divider Line
                          Container(
                            height: 60,
                            width: 1,
                            color: AppTheme.textSecondary.withValues(alpha: 0.15),
                          ),
                          // Right Column: Debtors
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DEBTORS',
                                    style: AppTheme.monoSecondary.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$debtorCount $debtorLabel',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '-₹${totalOwe.toStringAsFixed(2)}',
                                    style: AppTheme.monoStyle.copyWith(
                                      color: AppTheme.semanticNegative,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 16),

            // Join Group with Code Quick Action Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.accent),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.qr_code_outlined, size: 16, color: AppTheme.accent),
                    label: Text(
                      'JOIN GROUP WITH CODE',
                      style: AppTheme.monoStyle.copyWith(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    onPressed: _showJoinGroupByCodeDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Incoming Group Invites Card
            Consumer(
              builder: (context, ref, child) {
                final invitesAsync = ref.watch(incomingGroupInvitesProvider);
                final pendingInvites = invitesAsync.value ?? [];

                if (pendingInvites.isEmpty) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INCOMING GROUP INVITES',
                      style: AppTheme.monoStyle.copyWith(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                        color: AppTheme.surfaceCard.withValues(alpha: 0.2),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pendingInvites.length,
                        separatorBuilder: (context, index) => Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                        itemBuilder: (context, index) {
                          final invite = pendingInvites[index];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.group_add_outlined, color: AppTheme.accent, size: 20),
                            ),
                            title: Text(
                              invite.groupName,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Invited by ${invite.senderName}',
                                style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.accent),
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: () async {
                                    try {
                                      await ref.read(groupsRepositoryProvider).acceptGroupInvite(invite.inviteId, invite.groupId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Joined ${invite.groupName}!'), backgroundColor: AppTheme.accent),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.semanticNegative),
                                        );
                                      }
                                    }
                                  },
                                  child: Text('ACCEPT', style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.semanticNegative),
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  ),
                                  onPressed: () => ref.read(groupsRepositoryProvider).declineGroupInvite(invite.inviteId),
                                  child: Text('DECLINE', style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                );
              },
            ),

            // 2. Active Group Cards List
            if (groups.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                ),
                child: Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? 'No groups matching "${_searchQuery.trim()}"' : 'No active groups found.',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groups.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final memberCount = group.members.length;

                  return Consumer(
                    builder: (context, ref, child) {
                      final settlementAsync = ref.watch(groupSettlementProvider(group.groupId));

                      return InkWell(
                        onTap: () => context.push('/groups/${group.groupId}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceCard.withValues(alpha: 0.2),
                            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.people_outline, color: AppTheme.textSecondary, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$memberCount Members',
                                          style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              settlementAsync.when(
                                data: (state) {
                                  final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
                                  final myNet = state.netBalances[myUid] ?? 0.0;

                                  if (myNet > 0.01) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Owes You',
                                          style: AppTheme.monoSecondary.copyWith(fontSize: 9),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '+₹${myNet.toStringAsFixed(0)}',
                                          style: AppTheme.monoStyle.copyWith(
                                            color: AppTheme.semanticPositive,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    );
                                  } else if (myNet < -0.01) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'You Owe',
                                          style: AppTheme.monoSecondary.copyWith(fontSize: 9),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '-₹${myNet.abs().toStringAsFixed(0)}',
                                          style: AppTheme.monoStyle.copyWith(
                                            color: AppTheme.semanticNegative,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'SETTLED',
                                        style: AppTheme.monoSecondary.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                loading: () => const Text('...', style: TextStyle(color: AppTheme.textSecondary)),
                                error: (_, __) => const Text('Error', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    final myUid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(modalContext).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'NOTIFICATIONS',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () async {
                      if (myUid.isNotEmpty) {
                        await ref.read(notificationsRepositoryProvider).markAllAsRead(myUid);
                      }
                    },
                    child: Text(
                      'MARK ALL READ',
                      style: AppTheme.monoSecondary.copyWith(fontSize: 10, color: AppTheme.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: AppTheme.textSecondary.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final notificationsAsync = ref.watch(userNotificationsStreamProvider);

                    return notificationsAsync.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  'No notifications yet.',
                                  style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (context, index) => Divider(
                            color: AppTheme.textSecondary.withValues(alpha: 0.15),
                            height: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final item = list[index];
                            final timeStr = DateFormat('dd MMM, hh:mm a').format(item.createdAt).toUpperCase();

                            return Container(
                              color: item.isRead ? Colors.transparent : AppTheme.accent.withValues(alpha: 0.06),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceCard,
                                    border: Border.all(
                                      color: item.isRead
                                          ? AppTheme.textSecondary.withValues(alpha: 0.2)
                                          : AppTheme.accent.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.payments_outlined,
                                    color: item.isRead ? AppTheme.textSecondary : AppTheme.accent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  item.message,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        timeStr,
                                        style: AppTheme.monoSecondary.copyWith(fontSize: 9),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          item.groupName.toUpperCase(),
                                          style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontSize: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.accent),
                                onTap: () async {
                                  // 1. Mark notification as read
                                  await ref.read(notificationsRepositoryProvider).markAsRead(item.id);

                                  // 2. Pop notification sheet
                                  if (modalContext.mounted) {
                                    Navigator.pop(modalContext);
                                  }

                                  // 3. Redirect to group settlement screen!
                                  if (context.mounted && item.groupId.isNotEmpty) {
                                    context.push('/groups/${item.groupId}/settlement');
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
