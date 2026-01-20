/// Represents the message types defined in the Scaledrone V3 Protocol.
///
/// See: https://www.scaledrone.com/docs/api-v3-protocol
enum MessageType {
  /// Initial handshake message sent immediately upon connection.
  handshake,

  /// Authentication message for JWT-secured channels.
  authenticate,

  /// Request to subscribe to a room.
  subscribe,

  /// Request to unsubscribe from a room.
  unsubscribe,

  /// Standard message published to a room.
  publish,

  /// Initial list of members in an observable room.
  observable_members,

  /// Event when a new member joins an observable room.
  observable_member_join,

  /// Event when a member leaves an observable room.
  observable_member_leave,

  /// Special message type for retrieving past messages (history).
  /// Note: These are distinct from 'publish' messages.
  history_message,

  /// Initial ping/pong (handled automatically by WebSocket usually, but good to have).
  ping,

  /// Fallback for unknown message types from the server.
  unknown,
}

/// A strictly typed wrapper around the raw JSON payload from Scaledrone.
///
/// This class handles the polymorphism of the protocol
///  (e.g., `data` meaning different
/// things in different contexts) and sanitizes inputs.
class ScaledroneMessage {
  /// Internal constructor. Use [ScaledroneMessage.fromJson] factory.
  const ScaledroneMessage({
    required this.type,
    this.room,
    this.clientId,
    this.message,
    this.callback,
    this.error,
    this.id,
    this.timestamp,
    this.index,
    this.memberData,
  });

  /// Factory to create a message from a JSON map.
  ///
  /// This method manually parses the `type` string to the [MessageType] enum
  /// to ensure safety throughout the SDK.
  factory ScaledroneMessage.fromJson(Map<String, dynamic> json) {
    return ScaledroneMessage(
      type: _parseType(json['type'] as String?),
      room: json['room'] as String?,
      clientId: json['client_id'] as String?,
      // The 'message' field contains the actual user payload (String/Map/List)
      message: json['message'],
      callback: json['callback'] as int?,
      error: json['error'] as String?,
      // History specific fields
      id: json['id'] as String?,
      timestamp: json['timestamp'] as int?,
      index: json['index'] as int?,
      // Observable events use 'data' for user info
      memberData: json['data'],
    );
  }

  /// The type of message (e.g., publish, subscribe, handshake).
  final MessageType type;

  /// The room this message belongs to (optional).
  final String? room;

  /// The ID of the client who sent this message (optional).
  final String? clientId;

  /// The actual message payload. Can be [String], [Map], or [num].
  final dynamic message;

  /// The unique integer ID used to correlate requests with responses.
  ///
  /// If we send `callback: 5`,
  ///  the server response will also have `callback: 5`.
  final int? callback;

  /// If present, indicates the operation failed.
  final String? error;

  /// Unique ID of a history message.
  final String? id;

  /// Unix timestamp (in seconds) for history messages.
  final int? timestamp;

  /// The sort order index for history messages (0 = latest).
  final int? index;

  /// Data regarding members in observable rooms.
  ///
  /// This field maps to the `data` key in `observable_` events.
  final dynamic memberData;

  /// Converts the message back to JSON for sending over the socket.
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    // Only add type if it's not unknown
    if (type != MessageType.unknown) {
      // Scaledrone expects lowercase types
      //(e.g., "subscribe", not "MessageType.subscribe")
      data['type'] = type.name;
    }

    if (room != null) data['room'] = room;
    if (clientId != null) data['client_id'] = clientId;
    if (message != null) data['message'] = message;
    if (callback != null) data['callback'] = callback;

    // We rarely send these fields back, but good for completeness
    if (error != null) data['error'] = error;

    return data;
  }

  /// Helper to parse string types safely.
  static MessageType _parseType(String? type) {
    if (type == null) return MessageType.unknown;
    switch (type) {
      case 'handshake':
        return MessageType.handshake;
      case 'authenticate':
        return MessageType.authenticate;
      case 'subscribe':
        return MessageType.subscribe;
      case 'unsubscribe':
        return MessageType.unsubscribe;
      case 'publish':
        return MessageType.publish;
      case 'observable_members':
        return MessageType.observable_members;
      case 'observable_member_join':
        return MessageType.observable_member_join;
      case 'observable_member_leave':
        return MessageType.observable_member_leave;
      case 'history_message':
        return MessageType.history_message;
      case 'ping':
        return MessageType.ping;
      default:
        // Unknown types are handled gracefully
        return MessageType.unknown;
    }
  }

  @override
  String toString() {
    return ''' ScaledroneMessage(type: $type, room: $room, callback: $callback, error: $error)''';
  }
}
