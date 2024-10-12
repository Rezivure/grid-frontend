import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Import gestures for TapGestureRecognizer
import 'package:random_avatar/random_avatar.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher for opening URLs
import 'dart:async';
import 'dart:math';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Timer? _avatarTimer;
  int _avatarUpdateIndex = 0;

  @override
  void initState() {
    super.initState();

    // Initialize the fade-in animation controller
    _fadeController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Define a fade-in animation
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start the fade-in animation
    _fadeController.forward();

    // Start a timer to update avatars every second
    _avatarTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        _avatarUpdateIndex = DateTime.now().millisecondsSinceEpoch;
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose(); // Clean up the fade controller when the widget is disposed
    _avatarTimer?.cancel(); // Cancel the avatar update timer
    super.dispose();
  }

  // Function to launch URL in a browser
  Future<void> _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background, // Use theme background color
      body: Stack(
        children: [
          // Main content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Spacer(flex: 2), // Reduce the space above the logo
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Image.asset(
                    'assets/logos/png-file-2.png', // Display the logo
                    height: 250, // Make the logo even larger
                  ),
                ),
                const SizedBox(height: 20), // Decrease space between logo and avatar circle
                Container(
                  width: 250, // Width for the Stack
                  height: 250, // Height for the Stack
                  padding: const EdgeInsets.all(0), // Padding around the avatars
                  child: Stack(
                    alignment: Alignment.center,
                    children: _buildAvatarCircle(),
                  ),
                ),
                Spacer(flex: 1), // Increase the space below the circle to push it up
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Welcome to Grid',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary, // Use primary color for text
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text.rich(
                    TextSpan(
                      text: 'By using this app, you agree to our\n ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.6),
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: colorScheme.primary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _launchUrl('https://mygrid.app/privacy'); // Open privacy URL
                            },
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Terms of Service.',
                          style: TextStyle(
                            color: colorScheme.primary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _launchUrl('https://mygrid.app/terms'); // Open terms URL
                            },
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Spacer(flex: 1),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/server_select');
                    },
                    child: Text(
                      'Continue',
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
                ),
                const SizedBox(height: 10), // Space between the buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login'); // Navigate to the login screen
                    },
                    child: Text(
                      'Custom Provider',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.secondary, // Text color for custom provider
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20), // Space below buttons
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Function to build a circular stack of avatars
  List<Widget> _buildAvatarCircle() {
    final double radius = 100; // Radius of the circle
    final int avatarCount = 10; // Number of avatars in the circle
    final double avatarSize = 40; // Size of each avatar
    final double angleIncrement = (2 * pi) / avatarCount; // Angle between each avatar

    // Offset to move the entire circle down and to the right
    final double offsetX = 20;
    final double offsetY = 20;

    List<Widget> avatars = [];
    for (int i = 0; i < avatarCount; i++) {
      final double angle = i * angleIncrement;
      final double x = radius * cos(angle) + offsetX;
      final double y = radius * sin(angle) + offsetY;

      avatars.add(
        Positioned(
          left: x + radius - avatarSize / 2, // Adjust position for avatar size
          top: y + radius - avatarSize / 2, // Adjust position for avatar size
          child: RandomAvatar(
            _avatarUpdateIndex.toString() + i.toString(), // Randomize avatar based on time and index
            height: avatarSize,
            width: avatarSize,
          ),
        ),
      );
    }

    return avatars;
  }
}
