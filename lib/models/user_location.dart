// lib/models/user_location.dart

import 'package:latlong2/latlong.dart';

class UserLocation {
  final String userId;
  final LatLng position;
  final String timestamp;

  UserLocation({
    required this.userId,
    required this.position,
    required this.timestamp,
  });
}
