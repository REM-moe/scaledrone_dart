import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:scaledrone_dart/src/client.dart';

Future<void> main() async {
  // 1. Setup Logging to see protocol details
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    log('${record.level.name}: ${record.time}: ${record.message}');
  });

  // REPLACE THIS WITH YOUR CHANNEL ID FROM SCALEDRONE DASHBOARD
  const channelId = 'YOUR_CHANNEL_ID';

  if (channelId == 'YOUR_CHANNEL_ID') {
    log(
      '⚠️  Please replace YOUR_CHANNEL_ID with a real ID in example/main.dart',
    );
    exit(1);
  }

  log('--- Initializing Scaledrone Client ---');
  final client = ScaledroneClient(
    channelId,
    data: {'name': 'Dart Bot', 'color': '#ff0000'},
  );

  try {
    // 2. Connect
    await client.connect();
    log('✅ Connected! Client ID: ${client.clientId}');

    // 3. Subscribe to a normal room
    final room = await client.subscribe('my-room', historyCount: 5);

    // Listen for messages
    room.onMessage.listen((msg) {
      log('📩 Message in my-room: $msg');
    });

    // 4. Subscribe to an Observable room (must start with "observable-")
    final obsRoom = await client.subscribe('observable-room');

    // Listen for member updates
    obsRoom.onMembers.listen((members) {
      log('👥 Member List Updated: ${members.length} users online');
      for (final m in members) {
        log('   - ${m.id} (${m.data})');
      }
    });

    // 5. Publish a message
    log('📤 Publishing message...');
    room.publish({
      'text': 'Hello from Dart!',
      'time': DateTime.now().toString(),
    });

    // Keep process alive to receive messages
    // ignore: inference_failure_on_instance_creation
    await Future.delayed(const Duration(seconds: 10));

    // 6. Cleanup
    await client.disconnect();
    log('👋 Disconnected');
  } catch (e, stack) {
    log('❌ Error: $e');
    log(stack.toString());
  }
}
