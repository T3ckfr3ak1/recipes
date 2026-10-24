import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class SyncException implements Exception {
  SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

String describeSyncError(Object error) {
  if (error is SyncException) return error.message;
  if (error is FormatException) {
    final detail = error.message.trim();
    if (detail.isEmpty) {
      return 'The recipe repo returned data this app could not read.';
    }
    return 'The recipe repo returned data this app could not read. $detail';
  }
  if (error is TimeoutException) {
    return 'The recipe repo took too long to respond.';
  }
  if (error is SocketException || error is http.ClientException) {
    return "Couldn't reach the recipe repo. Saved recipes are still available.";
  }
  return error.toString();
}
