import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_mate/features/groups/domain/group_model.dart';

void main() {
  group('GroupModel Invite Code Serialization & Mapping Tests', () {
    test('GroupModel.fromMap parses inviteCode successfully', () {
      final map = {
        'name': 'Trip to Mumbai',
        'members': ['user-1', 'user-2'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 16)),
        'createdBy': 'user-1',
        'inviteCode': 'XYZ123',
      };

      final group = GroupModel.fromMap(map, 'group-abc');

      expect(group.groupId, 'group-abc');
      expect(group.name, 'Trip to Mumbai');
      expect(group.inviteCode, 'XYZ123');
      expect(group.members, contains('user-1'));
    });

    test('GroupModel.fromMap handles missing inviteCode gracefully (backward compatibility)', () {
      final map = {
        'name': 'Legacy Group',
        'members': ['user-1'],
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
        'createdBy': 'user-1',
      };

      final group = GroupModel.fromMap(map, 'group-legacy');

      expect(group.groupId, 'group-legacy');
      expect(group.inviteCode, isNull);
    });

    test('GroupModel.toMap serializes inviteCode correctly', () {
      final group = GroupModel(
        groupId: 'group-123',
        name: 'Weekend Getaway',
        members: ['user-1'],
        admins: ['user-1'],
        createdAt: DateTime(2026, 7, 16),
        createdBy: 'user-1',
        inviteCode: 'ABC456',
      );

      final map = group.toMap();

      expect(map['groupId'], 'group-123');
      expect(map['inviteCode'], 'ABC456');
      expect(map['name'], 'Weekend Getaway');
    });
  });
}
