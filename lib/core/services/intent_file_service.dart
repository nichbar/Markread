import 'dart:async';
import 'package:flutter/services.dart';

class IntentFile {
  final String path;
  final String name;

  const IntentFile({required this.path, required this.name});
}

class IntentFileService {
  static const _channel = MethodChannel('now.link.markread/files');

  final _fileController = StreamController<IntentFile>.broadcast();

  Stream<IntentFile> get onFileReceived => _fileController.stream;

  IntentFileService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileReceived') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _fileController.add(IntentFile(
          path: args['path'] as String,
          name: args['name'] as String,
        ));
      }
    });
  }

  Future<IntentFile?> getPendingFile() async {
    final result = await _channel.invokeMethod('getPendingFile');
    if (result == null) return null;
    final map = Map<String, dynamic>.from(result as Map);
    return IntentFile(
      path: map['path'] as String,
      name: map['name'] as String,
    );
  }

  void dispose() {
    _fileController.close();
  }
}
