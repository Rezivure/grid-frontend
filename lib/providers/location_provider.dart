import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final accuracy = LocationAccuracy.low; // Adjust as needed

  Position? get currentPosition => _currentPosition;

  Future<void> determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    _currentPosition = await Geolocator.getLastKnownPosition();
    notifyListeners();
  }

  void startLocationTracking() {
    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: 10,
        )
    ).listen((Position position) {
      _currentPosition = position;
      notifyListeners();
    }, onError: (e) {
      print('Error in getting location: $e');
    });
  }

  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: 10,
      ),
    );
  }

  @override
  void dispose() {
    stopLocationTracking();
    super.dispose();
  }
}
