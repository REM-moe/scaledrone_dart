/// A Dart SDK for Scaledrone (V3 Protocol).
///
/// This library provides:
/// 1. [ScaledroneClient]: A WebSocket client for Flutter apps (Connect, Chat, Listen).
/// 2. [ScaledroneRest]: An HTTP client for Server-side Dart (Push notifications, Stats).
library;

import 'package:scaledrone_dart/scaledrone_dart.dart' show ScaledroneClient, ScaledroneRest;

export 'src/client.dart';
export 'src/models/scaledrone_message.dart';
export 'src/rest_client.dart';
export 'src/room.dart';
