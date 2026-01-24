import 'dart:async';
import 'package:scaledrone_dart/scaledrone_dart.dart';
import 'package:scaledrone_dart/src/transport/scaledrone_transport.dart';
import 'package:scaledrone_dart/src/models/scaledrone_message.dart';
import 'package:test/test.dart';

class MockTransport extends ScaledroneTransport {
  final _messageController = StreamController<ScaledroneMessage>.broadcast();
  final List<Map<String, dynamic>> sentMessages = [];

  @override
  Stream<ScaledroneMessage> get onMessage => _messageController.stream;

  @override
  Future<ScaledroneMessage> sendRequest(Map<String, dynamic> payload) async {
    sentMessages.add(payload);
    return ScaledroneMessage(type: MessageType.unknown);
  }

  @override
  void sendMessage(Map<String, dynamic> payload) {
    sentMessages.add(payload);
  }

  void emit(ScaledroneMessage msg) {
    _messageController.add(msg);
  }
}

void main() {
  group('Room', () {
    late Room room;
    late MockTransport mockTransport;

    setUp(() {
      mockTransport = MockTransport();
      // Room constructor: Room(String name, ScaledroneTransport transport, [int? historyCount])
      room = Room('observable-test', mockTransport);
    });

    test('emits onMemberJoin when member joins', () async {
      final joinFuture = room.onMemberJoin.first;

      final memberData = {'id': 'member-1', 'name': 'Alice'};
      mockTransport.emit(ScaledroneMessage(
        type: MessageType.observable_member_join,
        room: 'observable-test',
        memberData: memberData,
      ));

      final member = await joinFuture;
      expect(member.id, equals('member-1'));
      expect(member.data, equals(memberData));
      expect(room.members.length, equals(1));
    });

    test('emits onMemberLeave when member leaves', () async {
      // First add a member
      final memberData = {'id': 'member-1'};
      mockTransport.emit(ScaledroneMessage(
        type: MessageType.observable_member_join,
        room: 'observable-test',
        memberData: memberData,
      ));
      
      await Future.delayed(Duration.zero);
      
      expect(room.members.length, equals(1));

      final leaveFuture = room.onMemberLeave.first;

      mockTransport.emit(ScaledroneMessage(
        type: MessageType.observable_member_leave,
        room: 'observable-test',
        memberData: {'id': 'member-1'},
      ));

      final member = await leaveFuture;
      expect(member.id, equals('member-1'));
      expect(room.members.length, equals(0));
    });
    
    test('unsubscribe sends unsubscribe message', () async {
      await room.unsubscribe();
      
      expect(mockTransport.sentMessages.length, equals(1));
      expect(mockTransport.sentMessages.first['type'], equals('unsubscribe'));
      expect(mockTransport.sentMessages.first['room'], equals('observable-test'));
    });
  });
}
