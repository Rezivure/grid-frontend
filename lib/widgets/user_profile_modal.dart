import 'package:flutter/material.dart';
import 'package:grid_frontend/utilities/utils.dart';
import 'package:random_avatar/random_avatar.dart'; // Import the random_avatar package

class UserProfileModal extends StatelessWidget {
  final String userId;
  final String displayName;
  final VoidCallback onAddFriend;

  UserProfileModal({
    required this.userId,
    required this.displayName,
    required this.onAddFriend,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RandomAvatar(
            userId.split(":").first.replaceFirst('@', ''), // Generate random avatar based on user ID
            height: 80.0, // Equivalent to the previous CircleAvatar radius of 40
            width: 80.0,
          ),
          SizedBox(height: 20),
          Text('@$displayName', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text('$userId'),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: onAddFriend,
            child: Text('Add Friend'),
          ),
        ],
      ),
    );
  }
}
