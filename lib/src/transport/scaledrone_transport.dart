import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:scaledrone_dart/src/models/scaledrone_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Manages the low-level WebSocket connection to Scaledrone.
class ScaledroneTransport {
  final Logger _log = Logger('ScaledroneTransport');

  WebSocketChannel? _channel;

  /// Global stream of parsed messages.
  final StreamController<ScaledroneMessage> _messageStream =
      StreamController.broadcast();

  final StreamController<void> _disconnectStream = StreamController.broadcast();

  /// Stream of all incoming Scaledrone messages.

  /// Stream when connection is closed or lost
  Stream<void> get onDisconnect => _disconnectStream.stream;

  /// Maps callback IDs to pending Futures.
  final Map<int, Completer<ScaledroneMessage>> _pendingRequests = {};

  int _callbackCounter = 0;

  /// Stream of all incoming Scaledrone messages.
  Stream<ScaledroneMessage> get onMessage => _messageStream.stream;

  /// Connects to the Scaledrone WebSocket URL.
  Future<void> connect(String url) async {
    _log.info('Connecting to $url...');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        _handleIncomingData,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
      );
      _log.info('WebSocket connection opened.');
    } catch (e) {
      _log.severe('Failed to connect', e);
      rethrow;
    }
  }

  /// Disconnects from the Scaledrone WebSocket.
  Future<void> disconnect() async {
    _log.info('Disconnecting...');
    await _channel?.sink.close();
    _channel = null;

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Disconnected'));
      }
    }
    _pendingRequests.clear();
  }

  /// Sends a request and awaits a server response with the same callback ID.
  Future<ScaledroneMessage> sendRequest(Map<String, dynamic> payload) {
    final completer = Completer<ScaledroneMessage>();
    final callbackId = _callbackCounter++;

    payload['callback'] = callbackId;
    _pendingRequests[callbackId] = completer;

    _log.fine('Sending Request (ID: $callbackId): ${payload['type']}');
    _sendJson(payload);

    return completer.future;
  }

  /// Sends a message without waiting for a response (Fire-and-forget).
  void sendMessage(Map<String, dynamic> payload) {
    _log.fine('Sending Message: ${payload['type']}');
    _sendJson(payload);
  }

  void _sendJson(Map<String, dynamic> data) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(data));
  }

  void _handleIncomingData(dynamic data) {
    try {
      // Ensure data is string (WebSocket might send bytes)
      final payloadString = data.toString();

      final jsonMap = jsonDecode(payloadString) as Map<String, dynamic>;
      final msg = ScaledroneMessage.fromJson(jsonMap);

      _log.finer('Received: $payloadString');

      // 1. Resolve pending request if callback ID matches
      if (msg.callback != null && _pendingRequests.containsKey(msg.callback)) {
        final completer = _pendingRequests.remove(msg.callback)!;

        if (msg.error != null) {
          _log.warning('Request ${msg.callback} failed: ${msg.error}');
          completer.completeError(Exception(msg.error));
        } else {
          _log.fine('Request ${msg.callback} succeeded.');
          if (!completer.isCompleted) {
            completer.complete(msg);
          }
        }
      } else if (msg.error != null) {
        _log.severe('Global Error: ${msg.error}');
      }

      // 2. Broadcast to Rooms
      _messageStream.add(msg);
    } catch (e, stack) {
      // Improved logging to show the actual error string
      _log.severe('Error processing incoming message: $e', e, stack);
    }
  }

  void _handleSocketError(dynamic error) {
    _log.severe('WebSocket Error', error);
    _messageStream.addError(error as Object);
    _disconnectStream.add(null);
  }

  void _handleSocketDone() {
    _log.info('WebSocket Closed.');
    _disconnectStream.add(null);
  }
}
