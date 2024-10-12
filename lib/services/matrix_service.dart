// lib/services/matrix_service.dart

import 'package:matrix/matrix.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MatrixService {
  final Client client;
  final FlutterSecureStorage secureStorage;

  MatrixService(String homeserver)
      : client = Client(homeserver),
        secureStorage = FlutterSecureStorage();

  Future<void> login(String username, String password) async {
    try {
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: username),
        password: password,
      );
      await secureStorage.write(key: 'access_token', value: client.accessToken);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await client.logout();
    await secureStorage.delete(key: 'access_token');
  }

  Future<void> restoreSession() async {
    final accessToken = await secureStorage.read(key: 'access_token');
    if (accessToken != null) {
      client.accessToken = accessToken;
      await client.sync();
    }
  }
}
