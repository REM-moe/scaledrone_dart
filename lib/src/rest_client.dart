import 'dart:convert';
import 'package:http/http.dart' as http;

/// A client for the Scaledrone REST API.
///
/// Use this for server-side logic
/// (e.g., system notifications, admin broadcasts)
/// where a persistent WebSocket connection is not needed.
///
/// See: https://www.scaledrone.com/docs/api-clients/rest
class ScaledroneRest {
  /// Creates a REST client.
  ///
  /// [channelId]: Your Channel ID.
  /// [secretKey]: Your Channel Secret (Found in dashboard).
  ///
  /// ⚠️ SECURITY WARNING: Never use this class in a Flutter app with your
  /// real Secret Key. This is intended for secure server-side environments.
  ScaledroneRest(this.channelId, this.secretKey)
    : _baseUrl = 'https://api2.scaledrone.com/$channelId';

  /// Your Channel ID.
  final String channelId;

  /// Your Channel Secret.
  final String secretKey;
  final String _baseUrl;

  /// Publishes a message to a specific room.
  ///
  /// [room]: The name of the room.
  /// [message]: The JSON serializable message.
  Future<void> publish(String room, dynamic message) async {
    final url = Uri.parse('$_baseUrl/$room/publish');
    await _post(url, message);
  }

  /// Publishes the same message to multiple rooms at once.
  ///
  /// [rooms]: A list of room names.
  /// [message]: The JSON serializable message.
  Future<void> publishToRooms(List<String> rooms, dynamic message) async {
    if (rooms.isEmpty) return;

    // Construct query parameters: ?r=room1&r=room2...
    final query = rooms.map((r) => 'r=${Uri.encodeComponent(r)}').join('&');
    final url = Uri.parse('$_baseUrl/publish/rooms?$query');

    await _post(url, message);
  }

  /// Gets the number of users in the channel.
  ///
  /// Returns a map usually containing `{"users_count": 20}`.
  Future<Future<dynamic>> getStats() async {
    final url = Uri.parse('$_baseUrl/stats');
    return _get(url);
  }

  /// Gets the list of users from all rooms.
  Future<List<String>> getAllMembers() async {
    final url = Uri.parse('$_baseUrl/members');
    final response = await _get(url);
    return List<String>.from(response as List);
  }

  /// Gets the list of active rooms (rooms that have users in them).
  Future<List<String>> getActiveRooms() async {
    final url = Uri.parse('$_baseUrl/rooms');
    final response = await _get(url);
    return List<String>.from(response as List);
  }

  /// Gets the list of users in a specific room.
  Future<List<String>> getRoomMembers(String roomName) async {
    final url = Uri.parse('$_baseUrl/$roomName/members');
    final response = await _get(url);
    return List<String>.from(response as List);
  }

  // --- Helpers ---

  Future<void> _post(Uri url, dynamic body) async {
    final response = await http.post(
      url,
      headers: _authHeaders,
      body: jsonEncode(body),
    );
    _checkError(response);
  }

  Future<dynamic> _get(Uri url) async {
    final response = await http.get(url, headers: _authHeaders);
    _checkError(response);
    return jsonDecode(response.body);
  }

  Map<String, String> get _authHeaders {
    // Basic Auth: base64(channel_id:secret_key)
    final credentials = base64Encode(utf8.encode('$channelId:$secretKey'));
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Basic $credentials',
    };
  }

  void _checkError(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception(
        'Scaledrone REST Error (${response.statusCode}): ${response.body}',
      );
    }
  }
}
