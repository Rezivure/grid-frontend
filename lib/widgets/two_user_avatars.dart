import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

class TwoUserAvatars extends StatelessWidget {
  final List<String> userIds;

  TwoUserAvatars({required this.userIds});

  @override
  Widget build(BuildContext context) {
    // Ensure there are at least two distinct avatars
    List<String> displayedUserIds = userIds.toSet().toList();
    if (displayedUserIds.length < 2) {
      displayedUserIds.add(displayedUserIds[0]);
    }
    displayedUserIds = displayedUserIds.take(2).toList();

    return CircleAvatar(
      radius: 30, // Adjust the size of the avatar
      backgroundColor: Colors.grey.shade200, // Background of the circle
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8, // Position the first avatar to the left
            child: RandomAvatar(
              displayedUserIds[0],
              height: 35,
              width: 35,
            ),
          ),
          Positioned(
            right: 8, // Position the second avatar to the right
            child: RandomAvatar(
              displayedUserIds[1],
              height: 35,
              width: 35,
            ),
          ),
        ],
      ),
    );
  }
}
