import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:scaledrone_dart/src/client.dart';

Future<void> main() async {
  // 1. Setup Logging to see protocol details
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  // REPLACE THIS WITH YOUR CHANNEL ID FROM SCALEDRONE DASHBOARD
  const channelId = 'YOUR_CHANNEL_ID';

  if (channelId == 'YOUR_CHANNEL_ID') {
    print(
      '⚠️  Please replace YOUR_CHANNEL_ID with a real ID in example/main.dart',
    );
    exit(1);
  }

  print('--- Initializing Scaledrone Client ---');
  final client = ScaledroneClient(
    channelId,
    data: {'name': 'Dart Bot', 'color': '#ff0000'},
  );

  try {
    // 2. Connect
    await client.connect();
    print('✅ Connected! Client ID: ${client.clientId}');

    // 3. Subscribe to a normal room
    final room = await client.subscribe('my-room', historyCount: 5);

    // Listen for messages
    room.onMessage.listen((msg) {
      print('📩 Message in my-room: $msg');
    });

    // 4. Subscribe to an Observable room (must start with "observable-")
    final obsRoom = await client.subscribe('observable-room');

    // Listen for member updates
    obsRoom.onMembers.listen((members) {
      print('👥 Member List Updated: ${members.length} users online');
      for (var m in members) {
        print('   - ${m.id} (${m.data})');
      }
    });

    // 5. Publish a message
    print('📤 Publishing message...');
    room.publish({
      'text': 'Hello from Dart!',
      'time': DateTime.now().toString(),
    });

    // Keep process alive to receive messages
    await Future.delayed(const Duration(seconds: 10));

    // 6. Cleanup
    await client.disconnect();
    print('👋 Disconnected');
  } catch (e, stack) {
    print('❌ Error: $e');
    print(stack);
  }
}
