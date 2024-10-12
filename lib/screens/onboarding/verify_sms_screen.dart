import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/auth_provider.dart';

class VerifySmsScreen extends StatefulWidget {
  @override
  _VerifySmsScreenState createState() => _VerifySmsScreenState();
}

class _VerifySmsScreenState extends State<VerifySmsScreen> {
  int _currentStep = 0; // 0: Enter Username, 1: Enter Phone Number, 2: Verify SMS Code
  bool _isLoginFlow = false;

  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _numberController1 = TextEditingController();
  final TextEditingController _numberController2 = TextEditingController();

  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  // Variables for username availability
  String _usernameStatusMessage = '';
  Color _usernameStatusColor = Colors.transparent;

  @override
  void initState() {
    super.initState();

    // Initialize number controllers with random numbers
    _numberController1.text = _generateRandomNumber().toString().padLeft(2, '0');
    _numberController2.text = _generateRandomNumber().toString().padLeft(2, '0');

    // Add listeners to username and number controllers to check username availability
    _usernameController.addListener(_onUsernameChanged);
    _numberController1.addListener(_onUsernameChanged);
    _numberController2.addListener(_onUsernameChanged);
  }

  int _generateRandomNumber() {
    return Random().nextInt(100); // Random number between 0 and 99
  }

  void _onUsernameChanged() {
    // Debounce or throttle calls if necessary
    _checkUsernameAvailability();
  }

  Future<void> _checkUsernameAvailability() async {
    // Build the username with numbers
    String username = _usernameController.text;
    String number1 = _numberController1.text;
    String number2 = _numberController2.text;

    String fullUsername = '$username.$number1.$number2';

    // Make sure username meets minimum requirements (e.g., not empty)
    if (username.isNotEmpty && number1.isNotEmpty && number2.isNotEmpty) {
      // Call the AuthProvider to check availability
      bool isAvailable = await Provider.of<AuthProvider>(context, listen: false)
          .checkUsernameAvailability(fullUsername);

      setState(() {
        if (isAvailable) {
          _usernameStatusMessage = 'Username is available';
          _usernameStatusColor = Colors.green;
        } else {
          _usernameStatusMessage = 'Username is not available';
          _usernameStatusColor = Colors.red;
        }
      });
    } else {
      setState(() {
        _usernameStatusMessage = '';
        _usernameStatusColor = Colors.transparent;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _numberController1.dispose();
    _numberController2.dispose();
    _phoneNumberController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Common elements
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        leading: BackButton(color: colorScheme.onBackground),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: _buildCurrentStep(context),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildUsernameStep(context);
      case 1:
        return _buildPhoneNumberStep(context);
      case 2:
        return _buildVerifySmsStep(context);
      default:
        return Container();
    }
  }

  Widget _buildUsernameStep(BuildContext context) {
    // Build the Enter Username UI
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RandomAvatar(
            _usernameController.text.isNotEmpty
                ? _usernameController.text.toLowerCase()
                : 'Grid',
            height: 100,
            width: 100,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: colorScheme.surface.withOpacity(0.1),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text('.'),
              const SizedBox(width: 5),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _numberController1,
                  decoration: InputDecoration(
                    labelText: '##',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: colorScheme.surface.withOpacity(0.1),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 5),
              Text('.'),
              const SizedBox(width: 5),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _numberController2,
                  decoration: InputDecoration(
                    labelText: '##',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: colorScheme.surface.withOpacity(0.1),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _usernameStatusMessage,
            style: TextStyle(color: _usernameStatusColor),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: (_usernameStatusMessage == 'Username is available')
                ? () {
              setState(() {
                _currentStep = 1; // Proceed to next step
              });
            }
                : null, // Disable button if username is not available
            child: Text(
              'Next',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() {
                _isLoginFlow = true;
                _currentStep = 1; // Go to phone number step for login
              });
            },
            child: Text(
              'Already have an account? Sign in.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary.withOpacity(0.8),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneNumberStep(BuildContext context) {
    // Build the Enter Phone Number UI
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            _isLoginFlow ? 'Sign In' : 'Register',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneNumberController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: colorScheme.surface.withOpacity(0.1),
              hintText: 'Enter your phone number',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              try {

                AuthProvider authProvider = Provider.of<AuthProvider>(context, listen: false);
                print("AuthProvider is available: $authProvider");
                await Provider.of<AuthProvider>(context, listen: false)
                    .sendSmsCode(
                  _phoneNumberController.text,
                  isLogin: _isLoginFlow,
                );
                setState(() {
                  _currentStep = 2; // Proceed to verify code step
                });
              } catch (e) {
                _showErrorDialog(context, 'Failed to send SMS code');
              }
            },
            child: Text(
              'Send Code',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifySmsStep(BuildContext context) {
    // Build the Verify SMS Code UI
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            width: 150,
            child: Lottie.network(
              'https://lottie.host/e8ebf51a-dd5f-4b40-8320-ca08f5041d13/LNsJZ0BVrk.json',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Please enter the code sent to your phone',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              try {
                await Provider.of<AuthProvider>(context, listen: false)
                    .sendSmsCode(
                  _phoneNumberController.text,
                  isLogin: _isLoginFlow,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Verification code resent')),
                );
              } catch (e) {
                _showErrorDialog(context, 'Failed to resend SMS code');
              }
            },
            child: Text(
              'Resend code?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary.withOpacity(0.8),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Verification Code',
              border: OutlineInputBorder(
                borderSide: BorderSide(),
              ),
              filled: true,
              fillColor: colorScheme.surface.withOpacity(0.1),
              hintText: 'Enter your 6-digit code',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (_codeController.text.length == 6) {
                if (_isLoginFlow) {
                  // Login flow
                  try {
                    await Provider.of<AuthProvider>(context, listen: false)
                        .verifyLoginCode(
                      _phoneNumberController.text,
                      _codeController.text,
                    );
                    // Navigate to home screen
                    Navigator.pushNamed(context, '/home');
                  } catch (e) {
                    _showErrorDialog(context, 'Login failed');
                  }
                } else {
                  // Register flow
                  String username =
                      '${_usernameController.text}.${_numberController1.text}.${_numberController2.text}';
                  try {
                    await Provider.of<AuthProvider>(context, listen: false)
                        .verifyRegistrationCode(
                      username,
                      _phoneNumberController.text,
                      _codeController.text,
                    );
                    // Navigate to home screen
                    Navigator.pushNamed(context, '/home');
                  } catch (e) {
                    _showErrorDialog(context, 'Registration failed');
                  }
                }
              } else {
                _showInvalidCodeDialog(context);
              }
            },
            child: Text(
              _isLoginFlow ? 'Sign In' : 'Register',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showInvalidCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Invalid Code'),
          content: Text('Please enter a valid 6-digit verification code.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    // Similar to _showInvalidCodeDialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
