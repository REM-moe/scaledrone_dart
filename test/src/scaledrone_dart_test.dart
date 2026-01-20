// ignore_for_file: strict_raw_type

import 'package:scaledrone_dart/src/models/scaledrone_message.dart';
import 'package:test/test.dart';

void main() {
  group('ScaledroneMessage', () {
    test('parses Handshake correctly', () {
      final json = {
        'type': 'handshake',
        'channel': '123',
        'callback': 0,
      };
      final msg = ScaledroneMessage.fromJson(json);
      expect(msg.type, MessageType.handshake);
      expect(msg.callback, 0);
    });

    test('parses Publish with complex payload correctly', () {
      final json = {
        'type': 'publish',
        'room': 'my-room',
        'message': {'text': 'hello', 'count': 1},
      };
      final msg = ScaledroneMessage.fromJson(json);
      expect(msg.type, MessageType.publish);
      expect(msg.room, 'my-room');
      expect(msg.message, isA<Map>());
      expect((msg.message as Map)['text'], 'hello');
    });

    test('parses History Message with index', () {
      final json = {
        'type': 'history_message',
        'id': 'msg_id',
        'timestamp': 1234567890,
        'index': 5,
        'message': 'old message',
      };
      final msg = ScaledroneMessage.fromJson(json);
      expect(msg.type, MessageType.history_message);
      expect(msg.index, 5);
      expect(msg.timestamp, 1234567890);
    });

    test('parses Observable Members', () {
      final json = {
        'type': 'observable_members',
        'data': [
          {'id': 'user1', 'color': 'red'},
          {'id': 'user2', 'color': 'blue'},
        ],
      };
      final msg = ScaledroneMessage.fromJson(json);
      expect(msg.type, MessageType.observable_members);
      expect(msg.memberData, isA<List>());
      expect((msg.memberData as List).length, 2);
    });

    test('handles unknown types gracefully', () {
      final json = {'type': 'future_feature_xyz'};
      final msg = ScaledroneMessage.fromJson(json);
      expect(msg.type, MessageType.unknown);
    });

    test('toJson serializes correctly', () {
      const msg = ScaledroneMessage(
        type: MessageType.subscribe,
        room: 'chat',
        callback: 1,
      );
      final json = msg.toJson();
      expect(json['type'], 'subscribe');
      expect(json['room'], 'chat');
      expect(json['callback'], 1);
    });
  });
}
