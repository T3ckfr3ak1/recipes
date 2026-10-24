import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'incoming_share.dart';

/// Android share target. Other platforms never emit shares.
final class ShareChannel {
  ShareChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('recipes/share');

  final MethodChannel _channel;
  final _incoming = StreamController<IncomingShare>.broadcast();

  Stream<IncomingShare> get shares => _incoming.stream;

  Future<void> start() async {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'shared') return;
      final share = IncomingShare.fromMap(call.arguments);
      if (share != null) _incoming.add(share);
    });
    final initial = await _channel.invokeMethod<Object?>('getInitialShare');
    final share = IncomingShare.fromMap(initial);
    if (share != null) _incoming.add(share);
  }

  void close() {
    unawaited(_incoming.close());
  }
}
