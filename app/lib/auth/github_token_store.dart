import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class GithubTokenStore {
  Future<String?> read();

  Future<void> write(String? token);
}

final class MemoryGithubTokenStore implements GithubTokenStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? token) async {
    final trimmed = token?.trim();
    value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

final class SecureGithubTokenStore implements GithubTokenStore {
  SecureGithubTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'github_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    final stored = await _storage.read(key: _key);
    final trimmed = stored?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Future<void> write(String? token) async {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _key);
      return;
    }
    await _storage.write(key: _key, value: trimmed);
  }
}
