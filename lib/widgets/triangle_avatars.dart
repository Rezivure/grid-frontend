import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import 'two_user_avatars.dart'; // Import the new TwoUserAvatars widget

class TriangleAvatars extends StatelessWidget {
  final List<String> userIds;

  TriangleAvatars({required this.userIds});

  @override
  Widget build(BuildContext context) {
    // Handle the case with exactly two avatars
    if (userIds.length == 2) {
      return TwoUserAvatars(userIds: userIds);
    }

    // Ensure we are only displaying up to 3 distinct avatars
    List<String> displayedUserIds = userIds.take(3).toList();

    return CircleAvatar(
      radius: 30, // Adjust the size of the overall circle
      backgroundColor: Colors.grey.shade200, // Background of the circle
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (displayedUserIds.length > 2)
            Positioned(
              top: 6, // Top avatar in the triangle
              child: RandomAvatar(
                displayedUserIds[0],
                height: 28,
                width: 28,
              ),
            ),
          if (displayedUserIds.length > 1)
            Positioned(
              bottom: 6,
              left: 6, // Bottom left avatar
              child: RandomAvatar(
                displayedUserIds[1],
                height: 28,
                width: 28,
              ),
            ),
          if (displayedUserIds.length > 2)
            Positioned(
              bottom: 6,
              right: 6, // Bottom right avatar
              child: RandomAvatar(
                displayedUserIds[2],
                height: 28,
                width: 28,
              ),
            ),
        ],
      ),
    );
  }
}
