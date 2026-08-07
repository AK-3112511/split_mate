import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/settlement_algorithm.dart';
import '../../auth/data/auth_repository.dart';
import '../data/friends_repository.dart';
import '../domain/friend_model.dart';

class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final _codeController = TextEditingController();
  bool _isAdding = false;
  String? _dialogError;

  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddFriendDialog(String myAppCode) async {
    _codeController.clear();
    _dialogError = null;
    _isAdding = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text(
                'ADD NEW FRIEND',
                style: AppTheme.monoStyle.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.0,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your friend\'s 6-character unique code to connect.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  if (_dialogError != null) ...[
                    Text(
                      _dialogError!,
                      style: AppTheme.monoStyle.copyWith(
                        color: AppTheme.semanticNegative,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _codeController,
                    autofocus: true,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    style: AppTheme.monoStyle.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'SM1234',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        letterSpacing: 4.0,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: AppTheme.surfaceBase,
                      border: OutlineInputBorder(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'YOUR CODE:',
                        style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: myAppCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Friend code copied to clipboard'),
                              backgroundColor: AppTheme.accent,
                            ),
                          );
                        },
                        child: Text(
                          myAppCode,
                          style: AppTheme.monoStyle.copyWith(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCEL', style: AppTheme.monoSecondary),
                ),
                TextButton(
                  onPressed: _isAdding
                      ? null
                      : () async {
                          final input = _codeController.text.trim().toUpperCase();
                          if (input.length != 6) {
                            setDialogState(() {
                              _dialogError = 'Code must be exactly 6 characters';
                            });
                            return;
                          }

                          setDialogState(() {
                            _isAdding = true;
                            _dialogError = null;
                          });

                          try {
                            await ref.read(friendsRepositoryProvider).addFriendByCode(input);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Friend request sent successfully'),
                                  backgroundColor: AppTheme.accent,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              _dialogError = e.toString().replaceFirst('Exception: ', '');
                              _isAdding = false;
                            });
                          }
                        },
                  child: _isAdding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent)),
                        )
                      : Text('CONNECT', style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsStreamProvider);
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;

    // Get current user's appCode
    String myAppCode = 'PENDING';
    if (currentUser != null) {
      ref.watch(friendDetailsProvider(currentUser.uid)).whenData((data) {
        if (data != null && data['appCode'] != null) {
          myAppCode = data['appCode'];
        }
      });
    }

    // Avatar configuration for current user
    final avatarDisplayName = currentUser?.displayName ?? 'User';
    final avatarInitials = avatarDisplayName.isNotEmpty
        ? avatarDisplayName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

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
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search friends by name or code...',
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
                'Friends',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
              ),
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
        child: friendsAsync.when(
          data: (friends) => _buildBody(friends, myAppCode),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  Widget _buildBody(List<FriendModel> friends, String myAppCode) {
    final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    final acceptedFriends = friends.where((f) => f.status == 'accepted').toList();

    final filteredAcceptedFriends = acceptedFriends.where((friend) {
      if (_searchQuery.trim().isEmpty) return true;
      final queryLower = _searchQuery.trim().toLowerCase();
      final details = ref.watch(friendDetailsProvider(friend.uid)).value;
      final name = (details?['displayName'] ?? '').toString().toLowerCase();
      final code = (details?['appCode'] ?? '').toString().toLowerCase();
      return name.contains(queryLower) || code.contains(queryLower);
    }).toList();
    
    // Distinguish incoming and outgoing pending requests
    final incomingRequests = friends
        .where((f) => f.status == 'pending' && f.sentBy != myUid)
        .toList();

    final outgoingRequests = friends
        .where((f) => f.status == 'pending' && f.sentBy == myUid)
        .toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connect card
            InkWell(
              onTap: () => _showAddFriendDialog(myAppCode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.8)),
                  color: Colors.transparent,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.person_add_alt_1_outlined, color: AppTheme.accent, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CONNECT WITH FRIEND',
                            style: AppTheme.monoStyle.copyWith(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add friend via unique code to send group invites & track splits.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.accent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pending Incoming Friend Invites
            if (incomingRequests.isNotEmpty) ...[
              Text(
                'INCOMING FRIEND REQUESTS',
                style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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
                  itemCount: incomingRequests.length,
                  separatorBuilder: (context, index) => Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                  itemBuilder: (context, index) {
                    final req = incomingRequests[index];
                    return _buildPendingRow(req, isIncoming: true);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Pending Outgoing Friend Invites
            if (outgoingRequests.isNotEmpty) ...[
              Text(
                'SENT FRIEND REQUESTS',
                style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: outgoingRequests.length,
                  separatorBuilder: (context, index) => Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                  itemBuilder: (context, index) {
                    final req = outgoingRequests[index];
                    return _buildPendingRow(req, isIncoming: false);
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Accepted Friends Header List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CONNECTED FRIENDS',
                  style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                Text(
                  'STATUS & BALANCE',
                  style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (filteredAcceptedFriends.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                ),
                child: Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? 'No friends matching "${_searchQuery.trim()}"' : 'No friends connected yet.',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                  ),
                ),
              )
            else ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredAcceptedFriends.length,
                  separatorBuilder: (context, index) => Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                  itemBuilder: (context, index) {
                    final friend = filteredAcceptedFriends[index];
                    return _buildFriendRow(friend);
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Entry Count Monospace Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ENTRY_COUNT',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${filteredAcceptedFriends.length.toString().padLeft(3, '0')} RECORDS',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRow(FriendModel req, {required bool isIncoming}) {
    final detailsAsync = ref.watch(friendDetailsProvider(req.uid));

    return detailsAsync.when(
      data: (details) {
        final name = details?['displayName'] ?? 'User';
        final avatarInitials = name.isNotEmpty
            ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
            : 'U';
        final photoUrl = details?['photoUrl'];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
            ),
            child: photoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Center(
                        child: Text(
                          avatarInitials,
                          style: AppTheme.monoStyle.copyWith(fontSize: 14, color: AppTheme.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      avatarInitials,
                      style: AppTheme.monoStyle.copyWith(fontSize: 14, color: AppTheme.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          title: Text(
            name,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              isIncoming ? 'Wants to connect' : 'Awaiting confirmation',
              style: AppTheme.monoSecondary.copyWith(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: isIncoming
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.accent),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      onPressed: () => ref.read(friendsRepositoryProvider).acceptFriendRequest(req.uid),
                      child: Text(
                        'ACCEPT',
                        style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.semanticNegative),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      onPressed: () => ref.read(friendsRepositoryProvider).declineFriendRequest(req.uid),
                      child: Text(
                        'DECLINE',
                        style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'PENDING',
                    style: AppTheme.monoStyle.copyWith(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
        );
      },
      loading: () => const ListTile(title: Text('Loading request details...')),
      error: (e, s) => ListTile(title: Text('Error: $e')),
    );
  }

  Widget _buildFriendRow(FriendModel friend) {
    final detailsAsync = ref.watch(friendDetailsProvider(friend.uid));
    final netBalanceAsync = ref.watch(friendNetBalanceProvider(friend.uid));
    final netBalance = netBalanceAsync.value ?? friend.balance;

    return detailsAsync.when(
      data: (details) {
        final name = details?['displayName'] ?? 'User';
        final avatarInitials = name.isNotEmpty
            ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
            : 'U';
        final photoUrl = details?['photoUrl'];

        // Balance coloring & formatting
        Color balanceColor = AppTheme.textSecondary;
        String balanceText = '₹0.00 SETTLED';
        String statusTag = 'ACCEPTED';

        if (netBalance > 0.01) {
          balanceColor = AppTheme.semanticPositive;
          balanceText = '+₹${netBalance.toStringAsFixed(2)} OWED TO YOU';
          statusTag = 'OWES YOU';
        } else if (netBalance < -0.01) {
          balanceColor = AppTheme.semanticNegative;
          balanceText = '-₹${netBalance.abs().toStringAsFixed(2)} YOU OWE';
          statusTag = 'YOU OWE';
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
            ),
            child: photoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Center(
                        child: Text(
                          avatarInitials,
                          style: AppTheme.monoStyle.copyWith(fontSize: 14, color: AppTheme.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      avatarInitials,
                      style: AppTheme.monoStyle.copyWith(fontSize: 14, color: AppTheme.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          title: Text(
            name,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              balanceText,
              style: AppTheme.monoStyle.copyWith(
                fontSize: 11,
                color: balanceColor,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: balanceColor.withValues(alpha: 0.1),
              border: Border.all(color: balanceColor == AppTheme.textSecondary ? AppTheme.accent.withValues(alpha: 0.4) : balanceColor.withValues(alpha: 0.6)),
            ),
            child: Text(
              statusTag,
              style: AppTheme.monoStyle.copyWith(
                color: balanceColor == AppTheme.textSecondary ? AppTheme.accent : balanceColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
      loading: () => const ListTile(title: Text('Loading details...')),
      error: (e, s) => ListTile(title: Text('Error: $e')),
    );
  }
}
