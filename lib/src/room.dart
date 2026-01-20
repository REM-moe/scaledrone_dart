import 'dart:async';
import 'package:logging/logging.dart';
import 'package:scaledrone_dart/src/client.dart';
import 'package:scaledrone_dart/src/models/scaledrone_message.dart';
import 'package:scaledrone_dart/src/transport/scaledrone_transport.dart';

/// Represents a member in an Observable Room.
class Member {
  // 'clientData' from handshake, 'authData' from JWT

  /// Creates a new Member instance from JSON data.
  Member({required this.id, this.data});

  /// Factory to create a Member from JSON map.
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      data: json, // Scaledrone often merges data at
      ///the root or within specific keys
    );
  }

  /// The unique client ID of the member.
  final String id;

  /// Custom data associated with the member (merged from handshake and JWT).
  final dynamic data;
}

/// A connection to a specific Scaledrone room.
///
/// Use [ScaledroneClient.subscribe] to obtain an instance.
class Room {
  /// Creates a new Room instance.
  Room(this.name, this._transport, [int? historyCount])
    : _log = Logger('Room:$name') {
    // Bind to the global transport stream
    _transport.onMessage.listen(_handleMessage);
  }

  final Logger _log;

  /// The name of the room (e.g., 'observable-room').
  final String name;
  final ScaledroneTransport _transport;

  // Stream Controllers
  final StreamController<dynamic> _messageController =
      StreamController.broadcast();
  final StreamController<List<Member>> _membersController =
      StreamController.broadcast();

  // State
  final List<Member> _members = [];

  // History Buffering
  final List<ScaledroneMessage> _historyBuffer = [];

  /// Stream of messages published to this room.
  ///
  /// Includes both live 'publish' messages and sorted 'history' messages.
  Stream<dynamic> get onMessage => _messageController.stream;

  /// Stream of member lists for Observable rooms.
  ///
  /// Emits a new list whenever someone joins or leaves.
  Stream<List<Member>> get onMembers => _membersController.stream;

  /// Current list of members (only populated for observable- rooms).
  List<Member> get members => List.unmodifiable(_members);

  /// Publishes a message to this room.
  void publish(dynamic message) {
    _transport.sendMessage({
      'type': 'publish',
      'room': name,
      'message': message,
    });
  }

  void _handleMessage(ScaledroneMessage msg) {
    // Only process messages for this room
    if (msg.room != name) return;

    try {
      switch (msg.type) {
        case MessageType.publish:
          _messageController.add(msg.message);

        case MessageType.history_message:
          _handleHistoryMessage(msg);

        case MessageType.observable_members:
          _handleObservableMembers(msg);

        case MessageType.observable_member_join:
          _handleMemberJoin(msg);

        case MessageType.observable_member_leave:
          _handleMemberLeave(msg);

        default:
          break;
      }
    } catch (e, stack) {
      _log.severe('Error handling message in room $name', e, stack);
    }
  }

  /// Buffers history messages and emits them when appropriate.
  ///
  /// Scaledrone sends history as individual events. We must sort them by index.
  void _handleHistoryMessage(ScaledroneMessage msg) {
    if (msg.index == null) return;

    _historyBuffer
      ..add(msg)
      ..sort(
        (a, b) => (b.index ?? 0).compareTo(a.index ?? 0),
      ); // Descending index?

    _messageController.add(msg.message);
  }

  void _handleObservableMembers(ScaledroneMessage msg) {
    if (msg.memberData is! List) {
      _log.warning(
        'Received observable_members but data is not a List: ${msg.memberData}',
      );
      return;
    }

    _members.clear();
    final list = msg.memberData as List<dynamic>;
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        _members.add(Member.fromJson(item));
      } else {
        _log.warning('Skipping invalid member item: $item');
      }
    }
    _membersController.add(List.unmodifiable(_members));
  }

  void _handleMemberJoin(ScaledroneMessage msg) {
    if (msg.memberData is! Map<String, dynamic>) {
      _log.warning(
        'Received observable_member_join but data is not a Map: ${msg.memberData}',
      );
      return;
    }

    final newMember = Member.fromJson(msg.memberData as Map<String, dynamic>);
    _members.add(newMember);
    _membersController.add(List.unmodifiable(_members));
    _log.info('Member joined: ${newMember.id}');
  }

  void _handleMemberLeave(ScaledroneMessage msg) {
    final leavingData = msg.memberData;
    // memberData usually contains {'id': '...'}
    if (leavingData is Map && leavingData.containsKey('id')) {
      final dynamic id = leavingData['id'];
      _members.removeWhere((m) => m.id == id);
      _membersController.add(List.unmodifiable(_members));
      _log.info('Member left: $id');
    } else {
      _log.warning(
        'Received observable_member_leave with invalid data: $leavingData',
      );
    }
  }
}
