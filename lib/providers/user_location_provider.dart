// lib/providers/user_location_provider.dart

import 'package:flutter/material.dart';
import 'package:grid_frontend/models/user_location.dart';

class UserLocationProvider with ChangeNotifier {
  Map<String, List<UserLocation>> _userLocationsBySubscreen = {};

  // Fetch locations based on the selected subscreen
  List<UserLocation> getUserLocations(String subscreen) {
    return _userLocationsBySubscreen[subscreen] ?? [];
  }

  // Update user locations for the selected subscreen
  void updateUserLocations(String subscreen, List<UserLocation> locations) {
    _userLocationsBySubscreen[subscreen] = locations;
    notifyListeners();
  }

  // Optional: Clear user locations for a subscreen
  void clearUserLocations(String subscreen) {
    _userLocationsBySubscreen.remove(subscreen);
    notifyListeners();
  }
}
