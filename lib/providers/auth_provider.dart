import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:grid_frontend/services/database_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:grid_frontend/utilities/utils.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String? _token;
  String? _userId;
  final Client client;
  final DatabaseService databaseService;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  String? get userId => _userId;

  AuthProvider(this.client, this.databaseService) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _token = prefs.getString('token');
    _userId = prefs.getString('userId');
    notifyListeners();
  }

  // Adjusted login to use JWT
  Future<void> loginWithJWT(String jwt) async {
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    //await prefs.setBool('isLoggedIn', _isLoggedIn);
    //await prefs.setString('token', jwt);

    try {
      // Check if we can communicate with the Matrix server
      await client.checkHomeserver(Uri.parse(dotenv.env['MATRIX_SERVER_URL']!));

      await client.login(
        LoginType.mLoginJWT, // Use JWT login type
        token: jwt,
      );

      await client.sync();

      final homeserver = await client.homeserver;
      log("Logged in to: $homeserver");
    } catch (e) {
      log('Error initializing Matrix client with JWT', error: e);
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _token = null;
    _userId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', _isLoggedIn);
    await prefs.remove('token');
    await prefs.remove('userId');

    notifyListeners();
  }

  Future<void> authenticateWithJWT(String jwt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('serverType', 'default');
      await loginWithJWT(jwt);
    } catch (e) {
      log('Failed to authenticate with JWT', error: e);
    }
  }

  Future<bool> requestDeactivateAccount(String phoneNumber) async {
    var clientID = client.userID;
    if (clientID == null) {
      log("Client ID is null");
      return false;
    }
    var curUser = localpart(clientID);
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['GAUTH_URL']!}/deactivate/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'username': curUser,
        }),
      );

      if (response.statusCode == 200) {
        log("Deactivation request sent successfully");
        return true;
      } else {
        log("Failed to send deactivation request: ${response.body}");
        return false;
      }
    } catch (e) {
      log('Error requesting deactivation', error: e);
      return false;
    }
  }

  String localpart(String userId) {
    return userId.split(":").first.replaceFirst('@', '');
  }

  Future<bool> confirmDeactivateAccount(String phoneNumber, String code) async {
    var clientID = client.userID;
    if (clientID == null) {
      log("Client ID is null");
      return false;
    }
    var username = localpart(clientID);
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['GAUTH_URL']!}/deactivate/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'phone_number': phoneNumber,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        log("Deactivation confirmed successfully");
        return true;
      } else {
        log("Failed to confirm deactivation code: ${response.body}");
        return false;
      }
    } catch (e) {
      log('Error verifying deactivation code', error: e);
      return false;
    }
  }

  Future<void> verifyLoginCode(String phoneNumber, String code) async {
    try {
      String deviceUuid = Uuid().v4();
      var response = await http.post(
        Uri.parse('${dotenv.env['GAUTH_URL']!}/login/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'code': code,
          'device_uuid': deviceUuid,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String jwt = data['jwt'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone_number', phoneNumber);
        await authenticateWithJWT(jwt);
      } else {
        throw Exception('Login verification failed');
      }
    } catch (e) {
      log('Error verifying login code', error: e);
      rethrow;
    }
  }

  Future<void> verifyRegistrationCode(String username, String phoneNumber, String code) async {
    try {
      String deviceUuid = Uuid().v4();
      var response = await http.post(
        Uri.parse('${dotenv.env['GAUTH_URL']!}/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'phone_number': phoneNumber,
          'code': code,
          'device_uuid': deviceUuid,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String jwt = data['jwt'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone_number', phoneNumber);
        await authenticateWithJWT(jwt);
      } else {
        throw Exception('Verification failed');
      }
    } catch (e) {
      log('Error verifying registration code', error: e);
      rethrow;
    }
  }

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      var response = await http.post(
        Uri.parse('${dotenv.env['GAUTH_URL']!}/username'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'phone_number': '+10000000000',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      log('Error checking username availability', error: e);
      return false;
    }
  }

  Future<void> sendSmsCode(String phoneNumber, {bool isLogin = false, String? username}) async {
    try {
      log("Sending SMS for ${isLogin ? 'Login' : 'Registration'}");

      String endpoint = isLogin ? '/login' : '/register';
      Map<String, dynamic> requestBody;

      if (isLogin) {
        requestBody = {'phone_number': phoneNumber};
      } else {
        if (username == null || username.isEmpty) {
          throw Exception('Username is required for registration');
        }
        requestBody = {'username': username, 'phone_number': phoneNumber};
      }

      var response = await http.post(
        Uri.parse('${dotenv.env['GAUTH_URL']!}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send SMS code');
      }
    } catch (e) {
      log('Error sending SMS code', error: e);
      rethrow;
    }
  }
}
