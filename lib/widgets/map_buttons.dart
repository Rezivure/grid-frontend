import 'package:flutter/material.dart';
import 'map_user_scroller.dart'; // Import the MapUserScroller component
import 'package:latlong2/latlong.dart'; // Import LatLng for positions

class MapButtons extends StatelessWidget {
  final VoidCallback onCenterUser;
  final VoidCallback onOrientNorth;
  final List<Map<String, dynamic>> friendAvatars; // List of friend avatars
  final Function(LatLng) onAvatarSelected; // Callback for selecting an avatar

  const MapButtons({
    Key? key,
    required this.onCenterUser,
    required this.onOrientNorth,
    required this.friendAvatars,
    required this.onAvatarSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Stack(
      children: [
        Positioned(
          right: 10,
          top: MediaQuery.of(context).size.height * 0.12,
          child: FloatingActionButton(
            heroTag: 'orientNorth',
            backgroundColor: Colors.white, // White background
            child: Icon(Icons.explore, color: primaryColor, size: 24), // Icon in primary color
            onPressed: onOrientNorth,
            mini: true, // Makes the button smaller
            shape: CircleBorder(), // Ensures the button is perfectly circular
            elevation: 4.0, // Adds some shadow for depth
          ),
        ),
        Positioned(
          right: 10,
          top: MediaQuery.of(context).size.height * 0.125 + 70,
          child: FloatingActionButton(
            heroTag: 'centerUser',
            backgroundColor: Colors.white, // White background
            child: Icon(Icons.my_location, color: primaryColor, size: 24), // Icon in primary color
            onPressed: onCenterUser,
            mini: true, // Makes the button smaller
            shape: CircleBorder(), // Ensures the button is perfectly circular
            elevation: 4.0, // Adds some shadow for depth
          ),
        ),
        // Conditionally render the MapUserScroller only if friendAvatars is not empty
        if (friendAvatars.isNotEmpty)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: MapUserScroller(
              friendAvatars: friendAvatars,
              onAvatarSelected: (LatLng position) {
                onAvatarSelected(position);
              },
            ),
          ),
        // Optionally, display a placeholder or a message if friendAvatars is empty
        if (friendAvatars.isEmpty)
          Positioned.fill(
            child: Center(
              child: Text('', style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }
}
