import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/groups_repository.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String inviteCode;

  const JoinGroupScreen({
    super.key,
    required this.groupId,
    required this.inviteCode,
  });

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  bool _isJoining = false;
  String? _errorMessage;

  Future<void> _handleJoin() async {
    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      await ref.read(groupsRepositoryProvider).joinGroupWithCode(widget.groupId, widget.inviteCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the group!'),
            backgroundColor: AppTheme.accent,
          ),
        );
        context.go('/groups/${widget.groupId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailsStreamProvider(widget.groupId));
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: groupAsync.when(
              data: (group) {
                if (group == null) {
                  return _buildErrorState('Invitation link is invalid or the group does not exist.');
                }

                if (group.inviteCode != widget.inviteCode) {
                  return _buildErrorState('Invalid invitation code for this group.');
                }

                if (group.members.contains(currentUid)) {
                  // User is already a member -> Redirect button to Group Detail
                  return _buildAlreadyJoinedState(group);
                }

                return _buildInvitationCard(group);
              },
              loading: () => const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
              error: (err, stack) => _buildErrorState('Error retrieving group details: $err'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationCard(dynamic group) {
    final memberCount = group.members.length;
    final formattedMembers = memberCount.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.2),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular group icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Icon(
                Icons.group_outlined,
                color: AppTheme.accent,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Pending Header
          Text(
            'INVITATION PENDING',
            style: AppTheme.monoSecondary.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Group Title (Serif Lora style)
          Text(
            group.name,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Member Count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, color: AppTheme.textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(
                '$formattedMembers MEMBERS',
                style: AppTheme.monoSecondary.copyWith(fontSize: 10, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Description Text
          Text(
            "You've been invited to join this group to manage shared expenses and track settlements.",
            style: AppTheme.monoSecondary.copyWith(
              fontSize: 11,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          // Join Button
          InkWell(
            onTap: _isJoining ? null : _handleJoin,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: AppTheme.accent,
              child: Center(
                child: _isJoining
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Text(
                        'Join group',
                        style: AppTheme.monoStyle.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cancel Action
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(
              'CANCEL',
              style: AppTheme.monoSecondary.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Footer info
          Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INV-CODE: #${widget.inviteCode.toUpperCase()}',
                style: AppTheme.monoSecondary.copyWith(fontSize: 9),
              ),
              Text(
                'SPLITMATE PROTOCOL',
                style: AppTheme.monoSecondary.copyWith(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyJoinedState(dynamic group) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.2),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 48),
          const SizedBox(height: 20),
          Text(
            'ALREADY A MEMBER',
            style: AppTheme.monoSecondary.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'You are already a member of "${group.name}". You can view shared balances directly.',
            style: AppTheme.monoSecondary.copyWith(fontSize: 11, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => context.go('/groups/${group.groupId}'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: AppTheme.accent,
              child: Center(
                child: Text(
                  'GO TO GROUP',
                  style: AppTheme.monoStyle.copyWith(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.2),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppTheme.semanticNegative, size: 48),
          const SizedBox(height: 20),
          Text(
            'INVITATION ERROR',
            style: AppTheme.monoSecondary.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.semanticNegative),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTheme.monoSecondary.copyWith(fontSize: 11, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => context.go('/'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  'RETURN HOME',
                  style: AppTheme.monoStyle.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
