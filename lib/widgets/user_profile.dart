import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

class UserProfile extends StatelessWidget {
  final String username;
  final String emoji;

  UserProfile({required this.username, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RandomAvatar(
          username, // Generate random avatar based on username
          height: 80, // Equivalent to the previous CircleAvatar radius of 40
          width: 80,
        ),
        SizedBox(height: 8),
        Text(
          '@$username',
          style: TextStyle(color: Colors.black, fontSize: 16),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
