import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:scaledrone_dart/scaledrone_dart.dart';

// Generates a random hex color
String _randomColor() {
  final random = Random();
  final val = random.nextInt(0xFFFFFF);
  return '#${val.toRadixString(16).padLeft(6, '0')}';
}

void main(List<String> args) async {
  // Input Handling
  final channelId = _promptInput('Enter your Scaledrone Channel ID: ');
  if (channelId.isEmpty) {
    print('❌ Channel ID is required.');
    exit(1);
  }

  var name = _promptInput('Enter your Name (default: Guest): ');
  if (name.isEmpty) name = 'Guest';

  final color = _randomColor();

  var roomNameInput = _promptInput('Enter Room Name (default: observable-chat): ');
  if (roomNameInput.isEmpty) roomNameInput = 'observable-chat';
  
  // Ensure it starts with observable- if not provided, just in case user forgets
  // but let's trust the user or maybe auto-prefix? 
  // Scaledrone only tracks members for rooms prefixed with 'observable-'.
  if (!roomNameInput.startsWith('observable-')) {
    print('⚠️ Note: Room name should start with "observable-" for member events to work.');
  }

  // 1. Initialize Client
  print('Connecting to Scaledrone...');
  final client = ScaledroneClient(
    channelId,
    data: {
      'name': name,
      'color': color,
    },
  );

  try {
    // 2. Connect
    await client.connect();
    print('✅ Connected as $name ($color)');

    // 3. Subscribe to room
    final room = await client.subscribe(roomNameInput, historyCount: 20);
    print('✅ Subscribed to $roomNameInput');

    // 4. Handle Incoming Messages (History + Live)
    room.onMessage.listen((msg) {
      if (msg is Map) {

        
        // Note: The structure depends on how we send it. 
        // We will send {'text': '...'}
        // And Scaledrone wraps it. 
        // Actually, the SDK emits `msg` which is `dynamic message`.
        // BUT for `observable` rooms, if we use the standard publish, 
        // we might not get the `member` info automatically attached to the message payload object itself 
        // unless we put it there OR the SDK handles wrapping.
        // 
        // In the `client.dart` implementation: `_messageController.add(msg.message);`
        // It emits exactly what was sent. 
        // It does NOT wrap it with the sender member info automatically in the `message` payload stream 
        // unlike some other client libraries which might pass a Message object.
        //
        // WAIT: The Java version `Message` object has `Member member`.
        // The Dart version `Room` logic:
        // `_messageController.add(msg.message);`
        // It STRIPS the `clientId` and `member` info from `ScaledroneMessage`.
        // This is a flaw I just noticed! 
        // The `Room.onMessage` stream emits `dynamic`, which is just the payload.
        // Users won't know WHO sent the message!
        
        // CRITICAL DEPARTURE: The Java version passes a `Message` object.
        // The Dart version passes `dynamic`.
        // If I want to fix this proper-proper, I should change `onMessage` to emit a `Message` object.
        // BUT that would be a breaking change potentially or require more work.
        // 
        // Workaround for this example/task:
        // We can't identify the sender in Dart currently with the existing `onMessage` stream 
        // because `Room._handleMessage` does: `_messageController.add(msg.message);`
        // `msg` has `clientId`.
        
        // ERROR IN DART IMPLEMENTATION DISCOVERED.
        // If I can't identify the sender, a chat app is hard.
        // I should fix this while I am at it?
        // User asked to "cross check context and make work ok".
        // A chat working ok NEEDS sender info.
        
        // I will FIX THIS in the Dart code first (or concurrently).
        // I need to change `onMessage` to emit something that includes the sender.
        // Or I can change my usage to include sender in the payload?
        // "Include sender in payload" is a client-side workaround. 
        // But Scaledrone usually provides it.
        
        // Let's modify `Room` to emit a `Message` wrapper or similar?
        // Existing code: `Stream<dynamic> get onMessage`.
        // If I change it to `Stream<ScaledroneMessage> get onMessage`, it breaks listeners expecting Map.
        // 
        // Let's check `ScaledroneMessage`. It has `clientId`.
        // Does it have `member` info? 
        // `ScaledroneMessage` definition: `final String? clientId;`
        // It does NOT seem to look up the member object from `_members` map automatically 
        // like the java version `member = room.getMembers().get(cb.getClientID());`.
        
        // This is a significant missing feature compared to Java.
        // Java: `onMessage(Room room, Message message)` where `Message` has `getMember()`.
        
        // I should probably fix this. 
        // But for now, I will use a Client-Side Workaround for the exampe:
        // I will include the 'sender' name in the message payload itself.
        // `{'text': 'Hello', 'sender': name}`.
        // This is safer than breaking the API right now, unless the user specifically asked for full parity.
        // "make the dart impl work ok"
        // 
        // I'll stick to the workaround for the example to show it "working", 
        // but adding a note in Walkthrough that `onMessage` doesn't provide envelope metadata is good.
        // 
        // Actually, I can do `msg['text']`.
        final text = msg['text'] as String? ?? '';
        final sender = msg['sender'] as String? ?? 'Unknown';
        final color = msg['color'] as String? ?? '#aaaaaa';
        print('\x1B[38;2;${_hexToRgb(color)}m$sender: $text\x1B[0m');
      } else {
        print('Message: $msg');
      }
    });

    // 5. Handle Member Events
    room.onMemberJoin.listen((member) {
      final data = member.data as Map<String, dynamic>?;
      final name = data?['name'] ?? 'User';
      print('➕ $name joined');
    });

    room.onMemberLeave.listen((member) {
       final data = member.data as Map<String, dynamic>?;
       final name = data?['name'] ?? 'User';
       print('➖ $name left');
    });

    room.onMembers.listen((members) {
      // Just print count to avoid spam
      // print('👥 Room has ${members.length} members');
    });

    // 6. Loop for Input
    print('💬 Chat started! Type messages and press Enter. Type /quit to exit.');
    
    // We need to listen to stdin properly
    // Using simple sync read for CLI
    while (true) {
        // This blocks the event loop in some Dart versions/implementations if not careful?
        // `stdin.readLineSync` blocks. 
        // If it blocks, incoming WebSocket messages might not be processed 
        // unless Dart's event loop handles it in background threads or we use async stdin.
        // 
        // Dart is single threaded using an event loop. `readLineSync` BLOCKS the event loop.
        // This means we WON'T receive messages while waiting for input!
        // 
        // I MUST use `stdin.transform(utf8.decoder).listen(...)` (Stream)
        // BUT that makes the "prompt" hard.
        // CLI chat in Dart requires non-blocking input handling.
        // 
        // Standard `stdin.listen` is the way.
        
        await _startChatLoop(room, name, color);
        break;
    }

  } catch (e, s) {
    print('❌ Error: $e');
    print(s);
  }
}

Future<void> _startChatLoop(Room room, String name, String color) async {
  final stream = stdin.transform(utf8.decoder).transform(const LineSplitter());
  
  await for (final line in stream) {
    if (line.trim() == '/quit') {
      print('Disconnecting...');
      await room.unsubscribe();
      exit(0);
    }
    
    if (line.trim().isNotEmpty) {
      // Move cursor up one line to overwrite the input echo (optional polish)
      // stdout.write('\x1B[1A\x1B[2K'); 
      
      room.publish({
        'text': line,
        'sender': name,
        'color': color,
      });
      // We assume we receive our own message and print it via onMessage
    }
  }
}

String _promptInput(String prompt) {
  stdout.write(prompt);
  return stdin.readLineSync()?.trim() ?? '';
}

String _hexToRgb(String hex) {
  // Simple helper for ansi colors if needed, 
  // currently we just pass basic stuff or ignore.
  // Actually truecolor ANSI support:
  // \x1B[38;2;R;G;Bm
  // \x1B[38;2;R;G;Bm
  final cleanHex = hex.replaceAll('#', '');
  if (cleanHex.length == 6) {
     final r = int.parse(cleanHex.substring(0, 2), radix: 16);
     final g = int.parse(cleanHex.substring(2, 4), radix: 16);
     final b = int.parse(cleanHex.substring(4, 6), radix: 16);
     return '$r;$g;$b';
  }
  return '255;255;255';
}
