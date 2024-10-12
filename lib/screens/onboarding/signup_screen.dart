import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:random_avatar/random_avatar.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late String _homeserver;
  late String _mapsUrl;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Retrieve the homeserver and mapsUrl passed from the previous screen
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>? ?? {};
    _homeserver = args['homeserver'] ?? 'matrix-dev.mygrid.app';
    _mapsUrl = args['mapsUrl'] ?? 'https://example.com/tiles.pmtiles';

    // Add listener to update the avatar dynamically as the user types
    _usernameController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background, // Use theme background color
      appBar: AppBar(
        leading: BackButton(color: colorScheme.onBackground), // Use theme color for back button
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView( // Make the content scrollable
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Add some vertical padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 50), // Add some space at the top
              RandomAvatar(
                _usernameController.text.isNotEmpty ? _usernameController.text.toLowerCase() : 'default',
                height: 100,
                width: 100,
              ),
              const SizedBox(height: 20),
              Text(
                'Sign Up',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary, // Use primary color for text
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Homeserver: $_homeserver',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Maps URL: $_mapsUrl',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'This will be your avatar!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixText: '@', // Add the @ symbol
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: const UnderlineInputBorder(), // Line underneath
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password (remember me!)',
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: const UnderlineInputBorder(), // Line underneath
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator(color: colorScheme.primary)
                  : ElevatedButton(
                onPressed: _signUp,
                child: Text(
                  'Sign Up',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary, // Text color in the button
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, // Button color
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/login',
                    arguments: {
                      'homeserver': _homeserver,
                      'mapsUrl': _mapsUrl,
                    },
                  );
                },
                child: Text(
                  'Already have an account? Sign In',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Username and password cannot be empty';
        _isLoading = false;
      });
      return;
    }

    final client = Provider.of<Client>(context, listen: false);

    try {
      // Ensure the client is logged out before attempting to register a new user
      if (client.isLogged()) {
        await client.logout();
      }

      await client.checkHomeserver(Uri.https(_homeserver.trim(), ''));

      await _registerUser(client, username, password);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign up: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _registerUser(Client client, String username, String password) async {
    try {
      final response = await client.register(
        kind: AccountKind.user,
        username: username,
        password: password,
        auth: null,
        deviceId: null,
        initialDeviceDisplayName: 'Grid App Device',
        inhibitLogin: false,
        refreshToken: true,
      );

      if (response.accessToken == null || response.userId == null) {
        throw Exception('Access token or user ID is null after registration.');
      }

      await _saveToken(response.accessToken!, response.userId!);

      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      if (e is MatrixException && e.errcode == 'M_FORBIDDEN') {
        await _handleAdditionalAuth(client, username, password, e.session);
      } else {
        setState(() {
          _errorMessage = 'Failed to sign up: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAdditionalAuth(Client client, String username, String password, String? session) async {
    try {
      final authData = AuthenticationData(
        type: 'm.login.dummy',
        session: session,
      );

      final response = await client.register(
        kind: AccountKind.user,
        username: username,
        password: password,
        auth: authData,
        deviceId: null,
        initialDeviceDisplayName: 'Grid App Device',
        inhibitLogin: false,
        refreshToken: true,
      );

      if (response.accessToken == null || response.userId == null) {
        throw Exception('Access token or user ID is null after registration.');
      }

      await _saveToken(response.accessToken!, response.userId!);

      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign up: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToken(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_id', userId);
    await prefs.setString('maps_url', _mapsUrl); // Save the map tile URL
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
