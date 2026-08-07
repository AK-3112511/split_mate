import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/groups/domain/group_model.dart';
import 'package:split_mate/features/groups/domain/group_invite_model.dart';

void main() {
  group('Group Admins & Invites Unit Tests', () {
    test('GroupModel.fromMap parses admins array correctly', () {
      final map = {
        'groupId': 'grp-100',
        'name': 'Trip to Goa',
        'members': ['user-1', 'user-2'],
        'admins': ['user-1'],
        'createdBy': 'user-1',
        'inviteCode': 'GOA123',
        'createdAt': '2026-08-03T12:00:00.000Z',
      };

      final group = GroupModel.fromMap(map, 'grp-100');
      expect(group.groupId, 'grp-100');
      expect(group.admins, ['user-1']);
      expect(group.admins.contains('user-1'), isTrue);
      expect(group.admins.contains('user-2'), isFalse);
    });

    test('GroupModel.fromMap falls back to createdBy if admins array is missing', () {
      final map = {
        'groupId': 'grp-101',
        'name': 'Weekend Party',
        'members': ['creator-uid', 'friend-uid'],
        'createdBy': 'creator-uid',
        'inviteCode': 'PRT999',
      };

      final group = GroupModel.fromMap(map, 'grp-101');
      expect(group.admins, ['creator-uid']);
    });

    test('GroupInviteModel parses and serializes correctly', () {
      final now = DateTime.now();
      final invite = GroupInviteModel(
        inviteId: 'inv-1',
        groupId: 'grp-100',
        groupName: 'Trip to Goa',
        senderUid: 'user-1',
        senderName: 'Alice',
        recipientUid: 'user-2',
        status: 'pending',
        createdAt: now,
      );

      final map = invite.toMap();
      expect(map['inviteId'], 'inv-1');
      expect(map['groupName'], 'Trip to Goa');
      expect(map['status'], 'pending');

      final parsed = GroupInviteModel.fromMap(map, 'inv-1');
      expect(parsed.groupName, 'Trip to Goa');
      expect(parsed.senderName, 'Alice');
      expect(parsed.status, 'pending');
    });

    test('GroupAdmin authority checks work correctly', () {
      final group = GroupModel(
        groupId: 'grp-200',
        name: 'Housemates',
        members: ['admin-1', 'member-1'],
        admins: ['admin-1'],
        createdAt: DateTime.now(),
        createdBy: 'admin-1',
        inviteCode: 'HSM123',
      );

      final isAdmin = group.admins.contains('admin-1');
      final isMemberAdmin = group.admins.contains('member-1');

      expect(isAdmin, isTrue);
      expect(isMemberAdmin, isFalse);
    });
  });
}
