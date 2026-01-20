# Scaledrone Dart SDK

A robust, strictly-typed Dart & Flutter client for the Scaledrone Real-time Messaging API (V3).  
This package provides a seamless way to add real-time capabilities to your Flutter apps (using WebSockets) and Dart backends (using REST).
```
Gemini has helped a lot 
```

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
    scaledrone_dart: ^0.1.0
```

Then run:

```sh
dart pub get
```

## Usage (Flutter / WebSocket)

The `ScaledroneClient` is designed for client-side applications (Flutter, Web, CLI).

### 1. Connect & Subscribe

```dart
import 'package:scaledrone_dart/scaledrone_dart.dart';

void main() async {
    // 1. Initialize the client
    final client = ScaledroneClient('YOUR_CHANNEL_ID', data: {
        'name': 'John Doe',
        'color': '#ff0000',
    });

    try {
        // 2. Connect
        await client.connect();
        print('Connected with ID: ${client.clientId}');

        // 3. Subscribe to a room
        // Optional: Ask for the last 50 messages
        final room = await client.subscribe('my-room', historyCount: 50);

        // 4. Listen for messages
        room.onMessage.listen((message) {
            print('New message: $message');
        });

        // 5. Publish a message
        room.publish({
            'text': 'Hello from Flutter!',
            'timestamp': DateTime.now().toIso8601String(),
        });

    } catch (e) {
        print('Error: $e');
    }
}
```

### 2. Observable Rooms (Who is online?)

To track users, simply prefix your room name with `observable-`. The SDK automatically handles the logic.

```dart
final room = await client.subscribe('observable-chat');

// Listen for the live list of members
room.onMembers.listen((members) {
    print('👥 Users Online: ${members.length}');
    
    for (var member in members) {
        // Access the data you sent during handshake (e.g., name, color)
        print('- ${member.id}: ${member.data}');
    }
});
```

### 3. Authentication (JWT)

If your channel requires authentication, you can authenticate after connecting but before subscribing to private rooms.

```dart
await client.connect();

// ... Call your backend to generate a JWT for client.clientId ...
final String jwt = await myBackend.fetchToken(client.clientId);

// Authenticate
await client.authenticate(jwt);

// Now you can subscribe to private rooms
client.subscribe('private-room');
```

## Usage (Server-Side / REST)

Use `ScaledroneRest` for backend logic (e.g., sending system alerts, banning users, or checking stats).  
**Never use this in a Flutter app, as it requires your Secret Key.**

```dart
import 'package:scaledrone_dart/scaledrone_dart.dart';

void main() async {
    // Initialize with Secret Key
    final api = ScaledroneRest('YOUR_CHANNEL_ID', 'YOUR_SECRET_KEY');

    // Broadcast a message (System Notification)
    await api.publish('notifications', {
        'alert': 'Server maintenance in 10 minutes.',
        'priority': 'high',
    });

    // Check how many users are online
    final stats = await api.getStats();
    print('Users online: ${stats['users_count']}');

    // Get list of active rooms
    final rooms = await api.getActiveRooms();
    print('Active rooms: $rooms');
}
```

## Architecture & Debugging

This package uses the [`logging`](https://pub.dev/packages/logging) package.  
To see protocol frames (like Handshake, Subscribe) in your console:

```dart
import 'package:logging/logging.dart';

void main() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
        print('${record.level.name}: ${record.time}: ${record.message}');
    });
    
    // ... run app
}
```

## Structure

- **ScaledroneClient:** Manages the persistent WebSocket connection.
- **Room:** Handles message streams, history buffering, and member lists.
- **ScaledroneRest:** Stateless HTTP client for server-side operations.

## Contributing

Pull requests are welcome!  
Please check the `test` folder for existing tests and ensure any new logic is covered.
