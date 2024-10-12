import 'package:flutter/material.dart';
import 'package:grid_frontend/widgets/map_user_scroller_avatar.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'package:grid_frontend/services/location_broadcast_service.dart';
import 'package:geolocator/geolocator.dart';

class MapUserScroller extends StatefulWidget {
  final List<Map<String, dynamic>> friendAvatars;
  final Function(LatLng) onAvatarSelected;

  const MapUserScroller({
    Key? key,
    required this.friendAvatars,
    required this.onAvatarSelected,
  }) : super(key: key);

  @override
  _MapUserScrollerState createState() => _MapUserScrollerState();
}

class _MapUserScrollerState extends State<MapUserScroller> {
  late PageController _pageController;
  int _currentIndex = 0;
  late int itemCount;
  late Map<String, dynamic> currentUserAvatar;

  @override
  void initState() {
    super.initState();

    // Retrieve the current user's data from RoomProvider and LocationBroadcastService
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final locationBroadcastService = Provider.of<LocationBroadcastService>(context, listen: false);
    final Position? currentPosition = locationBroadcastService.getLastKnownPosition();

    // Normalize userId by stripping the @ sign for comparison
    final String? currentUserId = roomProvider.userId?.replaceFirst('@', '');

    currentUserAvatar = {
      'userId': currentUserId,
      'position': currentPosition != null
          ? LatLng(currentPosition.latitude, currentPosition.longitude)
          : LatLng(0, 0),
    };

    // Debugging: Print user IDs
    //for (var friend in widget.friendAvatars) {
      //print(friend['userId']);
    //}

    // Normalize and filter out the current user from the friendAvatars list
    List<Map<String, dynamic>> filteredFriendAvatars = widget.friendAvatars
        .where((avatar) => avatar['userId'] != currentUserId)
        .toList();


    // Add the current user to the list
    List<Map<String, dynamic>> avatars = [
      currentUserAvatar,
      ...filteredFriendAvatars,
    ];

    if (avatars.length <= 3) {
      itemCount = avatars.length;
      _currentIndex = 0;
    } else {
      itemCount = avatars.length * 2000;
      int middleIndex = itemCount ~/ 2;
      middleIndex -= middleIndex % avatars.length;
      int currentUserIndex = avatars.indexWhere((avatar) => avatar['userId'] == currentUserId);
      _currentIndex = middleIndex + currentUserIndex;
    }

    _pageController = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.25,
    );

    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentIndex != next) {
        setState(() {
          _currentIndex = next;
          int userIndex = _currentIndex % avatars.length;
          widget.onAvatarSelected(avatars[userIndex]['position'] as LatLng);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Normalize and ensure that the current user's full userId is compared properly
    final String? currentUserId = currentUserAvatar['userId'];

    List<Map<String, dynamic>> filteredFriendAvatars = widget.friendAvatars
        .where((avatar) => avatar['userId'] != currentUserId)
        .toList();

    // Combine the current user and the filtered friends list
    List<Map<String, dynamic>> avatars = [
      currentUserAvatar,
      ...filteredFriendAvatars,
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 0.0),
        child: SizedBox(
          height: 125,
          child: PageView.builder(
            controller: _pageController,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              int avatarIndex = index % avatars.length;
              double scale = (_currentIndex % avatars.length == avatarIndex) ? 0.8 : 0.6;
              return TweenAnimationBuilder(
                duration: Duration(milliseconds: 300),
                tween: Tween<double>(begin: scale, end: scale),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: MapUserScrollableAvatar(
                      userId: avatars[avatarIndex]['userId'] as String,
                      size: 50,
                      isSelected: _currentIndex % avatars.length == avatarIndex, // Pass isSelected flag
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
