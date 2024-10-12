import 'package:grid_frontend/providers/location_provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'package:matrix/matrix.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async'; // Add this import for StreamSubscription

class LocationBroadcastService {
  final LocationProvider locationProvider;
  final RoomProvider roomProvider;

  LocationBroadcastService(this.locationProvider, this.roomProvider);

  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  final Duration _updateInterval = Duration(seconds: 60);
  StreamSubscription<Position>? _locationSubscription;

  void startBroadcastingLocation() {
    if (_locationSubscription != null) {
      print("Broadcast already started.");
      return;  // Avoid creating a new subscription if one is already active.
    }
    print("Location Broadcast Service Starting");

    _locationSubscription = locationProvider.getLocationStream().listen((position) {
      if (_shouldUpdateLocation(position)) {
        _updateRooms(position);
        _lastPosition = position;
        _lastUpdateTime = DateTime.now();
      }
    });
  }

  void stopBroadcastingLocation() {
    print("STOPPING");
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  bool _shouldUpdateLocation(Position position) {
    if (_lastPosition == null || _lastUpdateTime == null) return true;

    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    final timeElapsed = DateTime.now().difference(_lastUpdateTime!);

    return timeElapsed > _updateInterval;
  }
  void _updateRooms(Position position) {
    String? currentUserId = roomProvider.userId;

    List<Room> rooms = roomProvider.rooms;
    var roomsUpdated = 0;
    for (Room room in rooms) {
      // Get a list of members with Membership.join
      var joinedMembers = room.getParticipants().where((member) => member.membership == Membership.join).toList();

      // Only send the location event if there are at least two joined members, including the current user
      if (joinedMembers.length >= 2) {
        roomProvider.sendLocationEvent(room.id, position);
        roomsUpdated+=1;
      }
    }
    print("Updated a total of $roomsUpdated rooms with my location");
  }

  // Add this method to get the last known position
  Position? getLastKnownPosition() {
    return _lastPosition;
  }
}
