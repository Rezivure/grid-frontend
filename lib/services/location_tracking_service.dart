import 'package:flutter/material.dart';
import 'package:grid_frontend/services/database_service.dart';
import 'package:matrix/matrix.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class LocationTrackingService {
  final DatabaseService databaseService;
  final RoomProvider roomProvider;

  LocationTrackingService(this.databaseService, this.roomProvider);

  Timer? _timer;
  final Duration updateInterval = Duration(seconds: 30);


  void startService() {
    print("Location Tracking Service Starting");
    _timer =
        Timer.periodic(updateInterval, (Timer t) => periodicLocationTasks());
  }

  void stopService() {
    print("Location Tracking Service Stopping");
    _timer?.cancel();
  }


  Future<void> periodicLocationTasks() async {
    roomProvider.fetchAndUpdateLocations();
    //testPrintRecentLocations();
  }




  Future<Map<String, Map<String, dynamic>>> getMostRecentLocations() async {
    final locations = await databaseService.getUserLocations();
    Map<String, Map<String, dynamic>> userLocationMap = {};

    for (final location in locations) {
      final userId = location['userId'] as String;
      final latitude = location['latitude'] as double;
      final longitude = location['longitude'] as double;
      final timestamp = location['timestamp'] as String;

      userLocationMap[userId] = {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp,
      };
    }

    return userLocationMap;
  }
}
