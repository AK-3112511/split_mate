import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/notifications/data/notifications_repository.dart';
import 'package:split_mate/features/notifications/domain/notification_model.dart';

NotificationModel _n(String id, String type, {String sender = 'b', String? group, bool read = false}) =>
    NotificationModel(
      id: id,
      recipientUid: 'a',
      senderUid: sender,
      senderName: 'B',
      type: type,
      message: '',
      createdAt: DateTime(2026, 11, 16),
      isRead: read,
      groupId: group,
    );

void main() {
  final inbox = [
    _n('req-b', NotificationModel.friendRequest),
    _n('req-b-read', NotificationModel.friendRequest, read: true),
    _n('req-c', NotificationModel.friendRequest, sender: 'c'),
    _n('exp-b', NotificationModel.expenseAdded),
    _n('inv-g1', NotificationModel.groupInvite, group: 'g1'),
    _n('inv-g2', NotificationModel.groupInvite, group: 'g2'),
  ];

  test('accepting B\'s request only clears B\'s unread friend request', () {
    expect(
      NotificationsRepository.staleRequestIds(inbox, type: NotificationModel.friendRequest, senderUid: 'b'),
      ['req-b'],
    );
  });

  test('handling an invite only clears that group\'s invite', () {
    expect(
      NotificationsRepository.staleRequestIds(inbox, type: NotificationModel.groupInvite, groupId: 'g1'),
      ['inv-g1'],
    );
  });
}
