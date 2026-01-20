import 'dart:async';

import 'package:logging/logging.dart';
import 'package:scaledrone_dart/src/room.dart';
import 'package:scaledrone_dart/src/transport/scaledrone_transport.dart';

/// The main entry point for the Scaledrone SDK.
class ScaledroneClient {
  /// Creates a new client instance.
  ///
  /// [channelId]: Your Scaledrone Channel ID.
  /// [data]: Optional JSON data about this client (e.g., name, avatar),
  ///  to be sent during handshake.
  ScaledroneClient(this.channelId, {this.data});
  final Logger _log = Logger('ScaledroneClient');

  /// Your Scaledrone Channel ID.
  final String channelId;

  /// Optional JSON data about this client (e.g., name, avatar).
  final dynamic data; // Client data sent during handshake
  final ScaledroneTransport _transport = ScaledroneTransport();

  String? _clientId;

  /// The unique Client ID assigned by Scaledrone after handshake.
  String? get clientId => _clientId;

  /// Connects to Scaledrone and performs the Handshake.
  ///
  /// Throws an exception if connection or handshake fails.
  Future<void> connect() async {
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
      } else {
        throw Exception('Handshake response missing client_id');
      }
    } catch (e) {
      _log.severe('Handshake failed', e);
      await _transport.disconnect();
      rethrow;
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
    _log.info('Subscribing to room: $roomName');

    // Create the room wrapper immediately so it can start listening
    final room = Room(roomName, _transport, historyCount);

    final payload = <String, dynamic>{
      'type': 'subscribe',
      'room': roomName,
    };

    if (historyCount != null) {
      payload['history_count'] = historyCount;
    }

    await _transport.sendRequest(payload);
    _log.info('Subscribed to $roomName');

    return room;
  }

  /// Closes the connection.
  Future<void> disconnect() async {
    await _transport.disconnect();
  }
}
