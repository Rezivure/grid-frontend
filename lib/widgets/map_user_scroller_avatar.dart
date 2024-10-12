import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';

class MapUserScrollableAvatar extends StatelessWidget {
  final String userId;
  final double size;
  final bool isSelected; // Add the isSelected parameter

  const MapUserScrollableAvatar({
    Key? key,
    required this.userId,
    this.size = 50.0,
    this.isSelected = false, // Default to false
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Retrieve the current userId from RoomProvider
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final String? currentUserId = roomProvider.userId?.replaceFirst('@', '');

    // Determine the display name
    final username = userId.split(":").first.replaceFirst('@', '');
    final displayName = userId == currentUserId ? 'You' : username;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: isSelected
              ? BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.6),
                spreadRadius: 4,
                blurRadius: 15,
              ),
            ],
          )
              : null,
          child: RandomAvatar(
            username,
            height: size * 2,
            width: size,
          ),
        ),
        const SizedBox(height: 5), // Space between avatar and username
        Text(
          displayName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis, // Ensure the text does not overflow
          maxLines: 1, // Limit to one line
        ),
      ],
    );
  }
}
