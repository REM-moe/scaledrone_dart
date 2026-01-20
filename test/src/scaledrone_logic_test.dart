// ignore_for_file: inference_failure_on_instance_creation

import 'dart:async';
import 'package:scaledrone_dart/scaledrone_dart.dart';
import 'package:scaledrone_dart/src/transport/scaledrone_transport.dart';
import 'package:test/test.dart';

// Mock Transport to simulate socket messages without real connection
class MockTransport extends ScaledroneTransport {
  final _controller = StreamController<ScaledroneMessage>.broadcast();
  final List<Map<String, dynamic>> sentMessages = [];

  @override
  Stream<ScaledroneMessage> get onMessage => _controller.stream;

  @override
  void sendMessage(Map<String, dynamic> payload) {
    sentMessages.add(payload);
  }

  // Helper to simulate incoming message from server
  void emit(ScaledroneMessage msg) {
    _controller.add(msg);
  }
}

void main() {
  group('Room Logic Tests', () {
    late MockTransport mockTransport;
    late Room room;

    setUp(() {
      mockTransport = MockTransport();
      room = Room('test-room', mockTransport);
    });

    test('Scenario 1: Room ignores messages for other rooms', () async {
      final messages = <dynamic>[];
      room.onMessage.listen(messages.add);

      mockTransport
        ..emit(
          const ScaledroneMessage(
            type: MessageType.publish,
            room: 'test-room',
            message: 'hello world',
          ),
        )
        ..emit(
          const ScaledroneMessage(
            type: MessageType.publish,
            room: 'other-room',
            message: 'should be ignored',
          ),
        );

      await Future.delayed(Duration.zero);
      expect(messages, equals(['hello world']));
    });

    test('Scenario 2: History messages are emitted', () async {
      final messages = <dynamic>[];
      room.onMessage.listen(messages.add);

      mockTransport.emit(
        const ScaledroneMessage(
          type: MessageType.history_message,
          room: 'test-room',
          message: 'old message',
          index: 0,
          timestamp: 100,
        ),
      );

      await Future.delayed(Duration.zero);
      expect(messages, contains('old message'));
    });

    test('Scenario 3: Initial Observable Members list population', () async {
      final memberUpdates = <List<Member>>[];
      room.onMembers.listen(memberUpdates.add);

      // Using a flat structure to avoid nesting confusion
      final mockData = [
        {'id': 'user1', 'name': 'Alice'},
        {'id': 'user2', 'name': 'Bob'},
      ];

      mockTransport.emit(
        ScaledroneMessage(
          type: MessageType.observable_members,
          room: 'test-room',
          memberData: mockData,
        ),
      );

      await Future.delayed(Duration.zero);

      expect(room.members.length, 2);
      expect(room.members[0].id, 'user1');

      // Since we sent a flat map,
      //the data stored should contain 'name' directly
      final memberData = room.members[0].data as Map<String, dynamic>;
      expect(memberData['name'], 'Alice');

      expect(room.members[1].id, 'user2');
    });

    test('Scenario 4: Member Join event adds user', () async {
      mockTransport
        ..emit(
          const ScaledroneMessage(
            type: MessageType.observable_members,
            room: 'test-room',
            memberData: [],
          ),
        )
        ..emit(
          const ScaledroneMessage(
            type: MessageType.observable_member_join,
            room: 'test-room',
            memberData: {'id': 'user3', 'name': 'Charlie'},
          ),
        );

      await Future.delayed(Duration.zero);
      expect(room.members.length, 1);
      expect(room.members.first.id, 'user3');
    });

    test('Scenario 5: Member Leave event removes user', () async {
      mockTransport.emit(
        const ScaledroneMessage(
          type: MessageType.observable_members,
          room: 'test-room',
          memberData: [
            {'id': 'user1'},
            {'id': 'user2'},
          ],
        ),
      );

      await Future.delayed(Duration.zero);
      expect(room.members.length, 2);

      mockTransport.emit(
        const ScaledroneMessage(
          type: MessageType.observable_member_leave,
          room: 'test-room',
          memberData: {'id': 'user1'},
        ),
      );

      await Future.delayed(Duration.zero);
      expect(room.members.length, 1);
      expect(room.members.first.id, 'user2');
    });

    test('Scenario 6: Publish sends correct JSON payload', () {
      final payload = {'text': 'hi', 'priority': 1};
      room.publish(payload);

      expect(mockTransport.sentMessages.length, 1);
      final sent = mockTransport.sentMessages.first;

      expect(sent['type'], 'publish');
      expect(sent['room'], 'test-room');
      expect(sent['message'], payload);
    });

    test('Scenario 7: Handle malformed member data gracefully', () async {
      // If server sends bad data (String instead of List), it shouldn't crash
      mockTransport.emit(
        const ScaledroneMessage(
          type: MessageType.observable_members,
          room: 'test-room',
          memberData: 'Not a list',
        ),
      );

      await Future.delayed(Duration.zero);
      expect(true, true); // Passed if no crash
    });
  });
}
