import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:random_avatar/random_avatar.dart';

class UserMarker {
  final LatLng position;
  final String userId;

  UserMarker({required this.position, required this.userId});
}

class UserMarkers extends StatefulWidget {
  final List<UserMarker> users;

  const UserMarkers({Key? key, required this.users}) : super(key: key);

  @override
  _UserMarkersState createState() => _UserMarkersState();
}

class _UserMarkersState extends State<UserMarkers> {
  double markerSize = 50.0; // Default marker size

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: widget.users.map((user) {
        final username = user.userId.split(":").first.replaceFirst('@', '');

        return Marker(
          point: user.position,
          width: markerSize,
          height: markerSize + 30.0, // Increased height to accommodate the username box
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RandomAvatar(
                username,
                height: markerSize,
                width: markerSize,
              ),
              const SizedBox(height: 5), // Space between avatar and username
              Text(
                username,
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
          ),
        );
      }).toList(),
    );
  }
}
