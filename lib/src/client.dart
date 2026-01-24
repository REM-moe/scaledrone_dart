import 'dart:async';

import 'package:logging/logging.dart';
import 'package:scaledrone_dart/src/models/scaledrone_message.dart';
import 'package:scaledrone_dart/src/room.dart';
import 'package:scaledrone_dart/src/transport/scaledrone_transport.dart';

/// The main entry point for the Scaledrone SDK.
  /// The main entry point for the Scaledrone SDK.
class ScaledroneClient {
  /// Creates a new client instance.
  ///
  /// [channelId]: Your Scaledrone Channel ID.
  /// [data]: Optional JSON data about this client (e.g., name, avatar),
  ///  to be sent during handshake.
  /// [transport]: Optional transport for testing or custom implementation.
  ScaledroneClient(
    this.channelId, {
    this.data,
    ScaledroneTransport? transport,
  }) : _transport = transport ?? ScaledroneTransport();

  final Logger _log = Logger('ScaledroneClient');

  /// Your Scaledrone Channel ID.
  final String channelId;

  /// Optional JSON data about this client (e.g., name, avatar).
  final dynamic data; // Client data sent during handshake
  final ScaledroneTransport _transport;

  String? _clientId;

  /// The unique Client ID assigned by Scaledrone after handshake.
  String? get clientId => _clientId;

  /// Map of room name to Room instance for tracking subscriptions.
  final Map<String, Room> _activeRooms = {};

  /// Whether the client intentionally requested a disconnect.
  bool _intentionalDisconnect = false;

  /// Reconnection attempt counter.
  int _reconnectAttempts = 0;

  /// Connects to Scaledrone and performs the Handshake.
  ///
  /// Throws an exception if connection or handshake fails.
  /// Automatically attempts to reconnect on connection loss.
  Future<void> connect() async {
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;
    await _connectInternal();

    // Listen for disconnections to trigger auto-reconnect
    _transport.onDisconnect.listen((_) {
      if (!_intentionalDisconnect) {
        _log.warning('Disconnected unexpectedly. Attempting to reconnect...');
        _reconnect();
      }
    });

    // Listen for global messages (like ping)
    _transport.onMessage.listen(_handleGlobalMessage);
  }

  Future<void> _connectInternal() async {
    // 1. Open Socket
    await _transport.connect('wss://api.scaledrone.com/v3/websocket');

    // 2. Perform Handshake
    try {
      _log.info('Performing Handshake...');
      final response = await _transport.sendRequest({
        'type': 'handshake',
        'channel': channelId,
        'client_data': data,
      });

      if (response.clientId != null) {
        _clientId = response.clientId;
        _log.info('Handshake successful. Client ID: $_clientId');
        // Reset reconnect attempts on success
        _reconnectAttempts = 0;
      } else {
        throw Exception('Handshake response missing client_id');
      }
    } catch (e) {
      // If handshake fails, ensure we close the socket so we don't leak
      // or leave it in a half-open state.
      _log.severe('Handshake failed', e);
      await _transport.disconnect();
      rethrow;
    }
  }

  void _handleGlobalMessage(ScaledroneMessage msg) {
    if (msg.type == MessageType.ping) {
      _log.fine('Received Ping. Sending Pong.');
      _transport.sendMessage({
        'type': 'pong',
      });
    }
  }

  Future<void> _reconnect() async {
    if (_intentionalDisconnect) return;

    // Exponential Backoff: 2s, 4s, 8s ... max 30s
    final delaySeconds = (2 * (1 << _reconnectAttempts)).clamp(2, 30);
    _log.info(
      'Reconnecting in $delaySeconds seconds (Attempt ${_reconnectAttempts + 1})...',
    );

    await Future.delayed(Duration(seconds: delaySeconds));
    _reconnectAttempts++;

    try {
      await _connectInternal();
      _log.info('Reconnected successfully. Resubscribing to rooms...');
      // Resubscribe to all active rooms
      for (final roomName in _activeRooms.keys) {
        await _subscribeInternal(roomName, _activeRooms[roomName]);
      }
    } catch (e) {
      _log.severe('Reconnection failed: $e. Retrying...');
      _reconnect(); // Recurse/Retry
    }
  }

  /// Authenticates the client using a JWT.
  ///
  /// [token]: The JWT string provided by your backend.
  ///
  /// Note: Connection and Handshake must be complete before calling this.
  Future<void> authenticate(String token) async {
    if (_clientId == null) {
      throw Exception(
        'Cannot authenticate before connecting (missing client_id).',
      );
    }

    _log.info('Authenticating...');
    await _transport.sendRequest({
      'type': 'authenticate',
      'token': token,
    });
    _log.info('Authentication successful.');
  }

  /// Subscribes to a room.
  ///
  /// [roomName]: The name of the room. Prefix with `observable-` for presence
  /// features.
  /// [historyCount]: Number of past messages to fetch (Max 100).
  Future<Room> subscribe(String roomName, {int? historyCount}) async {
    if (_activeRooms.containsKey(roomName)) {
      return _activeRooms[roomName]!;
    }

    _log.info('Subscribing to room: $roomName');

    // Create the room wrapper immediately so it can start listening
    final room = Room(roomName, _transport, historyCount);
    _activeRooms[roomName] = room;

    await _subscribeInternal(roomName, room, historyCount: historyCount);
    return room;
  }

  Future<void> _subscribeInternal(
    String roomName,
    Room? room, {
    int? historyCount,
  }) async {
    final payload = <String, dynamic>{
      'type': 'subscribe',
      'room': roomName,
    };

    if (historyCount != null) {
      payload['history_count'] = historyCount;
    }
    // Note: Use room instance history count if available for re-sub?
    // Simplified for now.

    await _transport.sendRequest(payload);
    _log.info('Subscribed to $roomName');
  }

  /// Unsubscribes from a room.
  ///
  /// [roomName]: The name of the room to unsubscribe from.
  Future<void> unsubscribe(String roomName) async {
    if (!_activeRooms.containsKey(roomName)) {
      return;
    }

    _log.info('Unsubscribing from room: $roomName');
    
    // 1. Send Unsubscribe message
    await _transport.sendRequest({
      'type': 'unsubscribe',
      'room': roomName,
    });

    // 2. Remove from active rooms
    _activeRooms.remove(roomName);
    
    _log.info('Unsubscribed from $roomName');
  }

  /// Closes the connection.
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _activeRooms.clear();
    await _transport.disconnect();
  }
}
