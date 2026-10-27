import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models.dart';

sealed class StreamEvent {}

class FrameEvent extends StreamEvent {
  final FrameMeta meta;
  final Uint8List jpeg;
  FrameEvent(this.meta, this.jpeg);
}

class StatusEvent extends StreamEvent {
  final String message;
  final bool error;
  StatusEvent(this.message, this.error);
}

class ClosedEvent extends StreamEvent {
  final Object? error;
  ClosedEvent(this.error);
}

/// Cliente del WebSocket /ws/stream. El servidor envía un JSON y, si es un
/// frame, a continuación el JPEG en un mensaje binario.
class StreamClient {
  final Uri uri;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _events = StreamController<StreamEvent>.broadcast();
  FrameMeta? _pendingMeta;

  StreamClient(this.uri);

  Stream<StreamEvent> get events => _events.stream;
  bool get connected => _channel != null;

  Future<void> connect() async {
    await disconnect();
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    _channel = channel;
    _sub = channel.stream.listen(
      _onMessage,
      onError: (Object e) => _closed(e),
      onDone: () => _closed(null),
    );
  }

  void _onMessage(dynamic message) {
    if (message is String) {
      final data = jsonDecode(message) as Map<String, dynamic>;
      if (data['type'] == 'frame') {
        _pendingMeta = FrameMeta.fromJson(data);
      } else {
        _events.add(StatusEvent(data['message'] as String, data['error'] as bool? ?? false));
      }
    } else if (message is List<int> && _pendingMeta != null) {
      _events.add(FrameEvent(_pendingMeta!, Uint8List.fromList(message)));
      _pendingMeta = null;
    }
  }

  void _closed(Object? error) {
    if (_channel == null) return;
    _channel = null;
    _events.add(ClosedEvent(error));
  }

  Future<void> disconnect() async {
    final channel = _channel;
    _channel = null;
    await _sub?.cancel();
    _sub = null;
    await channel?.sink.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
