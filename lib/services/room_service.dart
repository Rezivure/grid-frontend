import 'dart:ffi';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:matrix/matrix.dart';
import 'package:grid_frontend/utilities/utils.dart';
import 'package:grid_frontend/services/user_service.dart';
import 'package:matrix/matrix_api_lite/generated/model.dart' as matrix_model;
import 'package:grid_frontend/repositories/user_repository.dart';
import 'package:grid_frontend/repositories/user_keys_repository.dart';
import 'package:grid_frontend/repositories/room_repository.dart';
import 'package:grid_frontend/repositories/location_repository.dart';
import 'package:grid_frontend/repositories/sharing_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_manager.dart';
import 'package:grid_frontend/models/room.dart' as GridRoom;

class RoomService {
  final UserService userService;
  final Client client;
  final UserRepository userRepository;
  final UserKeysRepository userKeysRepository;
  final RoomRepository roomRepository;
  final LocationRepository locationRepository;
  final SharingPreferencesRepository sharingPreferencesRepository;

  // Tracks recent messages/location updates sent to prevent redundant messages
  final Map<String, Set<String>> _recentlySentMessages = {};
  final int _maxMessageHistory = 50;

  bg.Location? _currentLocation;

  bg.Location? get currentLocation => _currentLocation;



  RoomService(
      this.client,
      this.userService,
      this.userRepository,
      this.userKeysRepository,
      this.roomRepository,
      this.locationRepository,
      this.sharingPreferencesRepository,
      LocationManager locationManager, // Inject LocationManager
      ) {
    // Subscribe to location updates
    locationManager.locationStream.listen((location) {
      // Update current location in room service
      _currentLocation = location;
      // Check if this is a targeted update
      if (location.extras?.containsKey('targetRoomId') == true) {
        String roomId = location.extras!['targetRoomId'];
        updateSingleRoom(roomId);
      } else {
        // Regular periodic update to all rooms
        updateRooms(location);
      }
    });
  }


  String getMyHomeserver() {
    return client.homeserver.toString();
  }

 /// create direct grid room (contact)
  Future<bool> createRoomAndInviteContact(String matrixUserId) async {



    // Check if the user exists
    try {
      print(matrixUserId);
      final exists = await userService.userExists(matrixUserId);
      if (!exists) {
        return false;
      }
    } catch (e) {
      print('User $matrixUserId does not exist: $e');
      return false;
    }

    // Check if direct grid contact already exists
    final myUserId = client.userID ?? 'error';

    // Use full Matrix IDs for relationship check to match getRelationshipStatus
    RelationshipStatus status = await userService.getRelationshipStatus(myUserId, matrixUserId);

    if (status == RelationshipStatus.canInvite) {
      final roomName = "Grid:Direct:$myUserId:$matrixUserId";
      final roomId = await client.createRoom(
        name: roomName,
        isDirect: true,
        preset: CreateRoomPreset.privateChat,
        invite: [matrixUserId],
        initialState: [
          StateEvent(
            type: 'm.room.encryption',
            content: {"algorithm": "m.megolm.v1.aes-sha2"},
          ),
        ],
      );
      return true; // success
    }
    return false; // failed
  }
  Future<bool> isUserInRoom(String roomId, String userId) async {
    Room? room = client.getRoomById(roomId);
    if (room != null) {
      var participants = room.getParticipants();
      return participants.any((user) => user.id == userId);
    }
    return false;
  }


  // In RoomService
  Future<String?> getUserRoomMembership(String roomId, String userId) async {
    Room? room = client.getRoomById(roomId);
    if (room != null) {
      var participants = room.getParticipants();
      try {
        final participant = participants.firstWhere(
              (user) => user.id == userId,
        );
        return participant.membership.name;
      } catch (e) {
        return 'invited';  // Default to invited if user not found
      }
    }
    return null;
  }

  /// Leaves a room
  Future<bool> leaveRoom(String roomId) async {
    try {
      final userId = await getMyUserId();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      final room = client.getRoomById(roomId);
      if (room != null) {
        try {
          await room.leave();
          await client.forgetRoom(roomId); // Add this line
        } catch (e) {
          print('Error leaving Matrix room (continuing with local cleanup): $e');
        }
      }

      await roomRepository.leaveRoom(roomId, userId);
      return true;
    } catch (e) {
      print('Error in leaveRoom: $e');
      return false;
    }
  }

  int getUserPowerLevel(String roomId, String userId) {
    final room = client.getRoomById(roomId);
    if (room != null) {
      final powerLevel = room.getPowerLevelByUserId(userId);
      return powerLevel;
    }
    return 0;
  }

  List<User> getFilteredParticipants(Room room, String searchText) {
    final lowerSearchText = searchText.toLowerCase();
    return room
        .getParticipants()
        .where((user) =>
    user.id != client.userID &&
        (user.displayName ?? user.id).toLowerCase().contains(lowerSearchText))
        .toList();
  }

  /// Fetches the list of participants in a room
  Future<List<User>> getRoomParticipants(String roomId) async {
    try {
      final room = client.getRoomById(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }
      return await room.getParticipants();
    } catch (e) {
      print('Error fetching room participants: $e');
      rethrow;
    }
  }

  int getPowerLevelByUserId(Room room, String userId) {
    return room.getPowerLevelByUserId(userId);
  }

  Future<List<Map<String, dynamic>>> getGroupRooms() async {
    try {
      await client.sync();
      List<Map<String, dynamic>> groupRooms = [];

      for (var room in client.rooms) {
        final participants = await room.getParticipants();
        if (room.name.contains("Grid:Group") &&
            room.membership == Membership.join) {
          groupRooms.add({
            'room': room,
            'participants': participants,
          });
        }
      }

      return groupRooms;
    } catch (e) {
      print("Error getting group rooms: $e");
      return [];
    }
  }

  Future<int> getNumInvites() async {
    try {
      await client.sync();
      List<Room> invitedRooms = client.rooms.where((room) =>
      room.membership == Membership.invite).toList();
      return invitedRooms.length;
    } catch (e) {
      print("Error fetching invites: $e");
      return 0;
    }
  }

  Future<bool> acceptInvitation(String roomId) async {
    try {
      print("Attempting to join room: $roomId");

      // Attempt to join the room
      await client.joinRoom(roomId);
      print("Successfully joined room: $roomId");

      // Check if the room exists
      final room = client.getRoomById(roomId);
      if (room == null) {
        print("Room not found after joining.");
        return false; // Invalid invite
      }

      // Optionally, you can check participants
      final participants = await room.getParticipants();
      final hasValidParticipant = participants.any(
            (user) => user.membership == Membership.join && user.id != client.userID,
      );

      if (!hasValidParticipant) {
        print("No valid participants found, leaving the room.");
        await leaveRoom(roomId);
        return false; // Invalid invite
      }
      return true; // Successfully joined
    } catch (e) {
      print("Error during acceptInvitation: $e");
      await leaveRoom(roomId);
      return false; // Failed to join
    }
  }

  Future<void> declineInvitation(String roomId) async {
    try {
      await client.leaveRoom(roomId);
    } catch (e) {
      print("Error declining invitation: $e");
    }
  }

  Future<bool> checkIfInRoom(String roomId) async {
    try {
      final roomExists = client.rooms.any((room) => room.id == roomId);
      if (roomExists) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Failed to check if room exists");
      return false;
    }
  }

  Future<void> cleanRooms() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final myUserId = client.userID;
      print("Checking for rooms to clean at timestamp: $now");

      for (var room in client.rooms) {
        print("trying to get rooms");
        final participants = await room.getParticipants();
        bool shouldLeave = false;
        String leaveReason = '';

        // Check if it's a Grid room (direct or group)
        if (room.name.startsWith("Grid:")) {
          print("Checking Grid room: ${room.name}");

          if (room.name.contains("Grid:Group:")) {
            // Handle group rooms
            final roomNameParts = room.name.split(":");
            if (roomNameParts.length >= 4) {
              final expirationTimestamp = int.tryParse(roomNameParts[2]) ?? 0;
              print("Group room ${room.id} expiration: $expirationTimestamp");

              if (expirationTimestamp > 0 && expirationTimestamp < now) {
                shouldLeave = true;
                leaveReason = 'expired group';
              }
            }
          } else if (room.name.contains("Grid:Direct:")) {
            // Handle direct rooms
            print("Checking direct room: ${room.id} with ${participants.length} participants");

            if (participants.length <= 1) {
              shouldLeave = true;
              leaveReason = 'solo direct room';
            } else if (participants.length == 2 &&
                participants.every((p) => p.membership != Membership.join)) {
              shouldLeave = true;
              leaveReason = 'no active participants in direct room';
            }
          }
        } else {
          // Non-Grid rooms should be left
          print("Found non-Grid room: ${room.name}");
          shouldLeave = true;
          leaveReason = 'non-Grid room';
        }

        // Extra checks for any room type
        if (!shouldLeave && participants.length == 1 &&
            participants.first.id == myUserId &&
            participants.first.membership == Membership.join) {
          shouldLeave = true;
          leaveReason = 'solo member room';
        }

        if (shouldLeave) {
          try {
            print("Leaving room ${room.id} (${room.name}) - Reason: $leaveReason");

            // Perform local cleanup before leaving the room
            await _cleanupLocalData(room.id, participants);

            // Leave and forget the room on the server
            await room.leave();
            await client.forgetRoom(room.id);
            print('Successfully left and forgot room: ${room.id}');
          } catch (e) {
            print('Error leaving room ${room.id}: $e');
          }
        } else {
          print("Keeping room ${room.id} (${room.name})");
        }
      }
      print("Room cleanup completed");
    } catch (e) {
      print("Error during room cleanup: $e");
    }
  }

  /// Handles cleanup of local data when leaving a room
  Future<void> _cleanupLocalData(String roomId, List<User> matrixUsers) async {
    try {
      print("Starting local cleanup for room: $roomId");

      // Get all user IDs in the room before deletion
      final userIds = matrixUsers.map((p) => p.id).toList();

      // Get list of direct contacts (these are already GridUsers)
      final directContacts = await userRepository.getDirectContacts();
      final directContactIds = directContacts.map((contact) => contact.userId).toSet();

      // Start with removing room participants
      await roomRepository.removeAllParticipants(roomId);

      // For each user in the room
      for (final userId in userIds) {
        // Skip if user is a direct contact
        if (directContactIds.contains(userId)) {
          print("User $userId is a direct contact, preserving user data");
          // Just remove the relationship for this room
          await userRepository.removeUserRelationship(userId, roomId);
          continue;
        }

        // Check if user has any other rooms
        final otherRooms = await userRepository.getUserRooms(userId);
        otherRooms.remove(roomId); // Remove current room from list

        if (otherRooms.isEmpty) {
          print("User $userId has no other rooms and is not a contact, cleaning up user data");
          // Remove user's location data
          await locationRepository.deleteUserLocations(userId);
          // Remove user and their relationships (this handles both GridUser and relationships)
          await userRepository.deleteUser(userId);
        } else {
          print("User $userId exists in other rooms, keeping user data");
          // Just remove the relationship for this room
          await userRepository.removeUserRelationship(userId, roomId);
        }
      }

      // Finally delete the room itself
      await roomRepository.deleteRoom(roomId);

      print("Completed local cleanup for room: $roomId");
    } catch (e) {
      print("Error during local cleanup for room $roomId: $e");
      // Re-throw the error to be handled by the calling function
      rethrow;
    }
  }


  Future<String> createGroup(String groupName, List<String> userIds, int durationInHours) async {
    String? effectiveUserId = client.userID ?? client.userID?.localpart;
    if (effectiveUserId == null) {
      return "Error";
    }

    // Calculate expiration timestamp
    int expirationTimestamp;
    if (durationInHours == 0) {
      // Infinite duration, set expiration to 0
      expirationTimestamp = 0;
    } else {
      // Calculate expiration time based on current time and duration
      final expirationTime = DateTime.now().add(Duration(hours: durationInHours));
      expirationTimestamp = expirationTime.millisecondsSinceEpoch ~/ 1000; // Convert to Unix timestamp
    }

    final roomName = "Grid:Group:$expirationTimestamp:$groupName:$effectiveUserId";
    var roomId = "";
    try {
      // Create power levels content that restricts invites to admin only
      final powerLevelsContent = {
        "ban": 50,
        "events": {
          "m.room.name": 50,
          "m.room.power_levels": 100,
          "m.room.history_visibility": 100,
          "m.room.canonical_alias": 50,
          "m.room.avatar": 50,
          "m.room.tombstone": 100,
          "m.room.server_acl": 100,
          "m.room.encryption": 100,
        },
        "events_default": 0,
        "invite": 100,
        "kick": 100,
        "notifications": {
          "room": 50
        },
        "redact": 50,
        "state_default": 50,
        "users": {
          effectiveUserId: 100,
        },
        "users_default": 0
      };

      // Create the room with power levels and encryption
      roomId = await client.createRoom(
        name: roomName,
        isDirect: false,
        visibility: matrix_model.Visibility.private,
        initialState: [
          StateEvent(
            type: EventTypes.Encryption,
            content: {"algorithm": "m.megolm.v1.aes-sha2"},
          ),
          StateEvent(
            type: EventTypes.RoomPowerLevels,
            content: powerLevelsContent,
          ),
        ],
      );

      // Invite users to the room
      for (String id in userIds) {
        if (id != effectiveUserId) {
          id = id.toLowerCase();
          var fullUsername = '@' + id + ':' + client.homeserver.toString().replaceFirst('https://', '');
          await client.inviteUser(roomId, fullUsername);
        }
      }

      // Add the "Grid Group" tag to the room
      await client.setRoomTag(client.userID!, roomId, "Grid Group");
    } catch (e) {
      // Handle errors
      print('Error creating room: $e');
      return "Error";
    }
    return roomId;
  }

  void getAndUpdateDisplayName() async {

    final prefs = await SharedPreferences.getInstance();
    var userID = client.userID ?? "";
    var displayName = await client.getDisplayName(userID) ?? '';
    if (displayName != null) {
      prefs.setString('displayName', displayName);
    }
  }

  void sendLocationEvent(String roomId, bg.Location location) async {
    final room = client.getRoomById(roomId);
    if (room == null || room.membership != Membership.join) {
      print("Skipping location update for room $roomId - no longer a member");
      return;
    }
    if (room != null) {
      final latitude = location.coords.latitude;
      final longitude = location.coords.longitude;

      if (latitude != null && longitude != null) {
        // Create a unique hash for the location message
        final messageHash = '$latitude:$longitude';

        // Check if the message is already sent
        if (_recentlySentMessages[roomId]?.contains(messageHash) == true) {
          print("Duplicate location event skipped for room $roomId");
          return;
        }

        // Build the event content
        final eventContent = {
          'msgtype': 'm.location',
          'body': 'Current location',
          'geo_uri': 'geo:$latitude,$longitude',
          'description': 'Current location',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        };

        try {
          await room.sendEvent(eventContent);
          print("Location event sent to room $roomId: $latitude, $longitude");

          // Track the sent message
          _recentlySentMessages.putIfAbsent(roomId, () => {}).add(messageHash);

          // Trim history if needed
          if (_recentlySentMessages[roomId]!.length > _maxMessageHistory) {
            _recentlySentMessages[roomId]!.remove(_recentlySentMessages[roomId]!.first);
          }
        } catch (e) {
          print("Failed to send location event: $e");
        }
      } else {
        print("Latitude or Longitude is null");
      }
    } else {
      print("Room $roomId not found");
    }
  }

  Future<int> getRoomMemberCount(String roomId) async {
    final room = client.getRoomById(roomId);
    if (room == null) return 0;

    return room
        .getParticipants()
        .where((member) =>
    member.membership == Membership.join ||
        member.membership == Membership.invite)
        .length;
  }

  Future<void> updateRooms(bg.Location location) async {
    List<Room> rooms = client.rooms;
    print("Grid: Found ${rooms.length} total rooms to process");

    final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (Room room in rooms) {
      try {
        print("Grid: Processing room ${room.name} (${room.id})");

        // Skip non-Grid rooms
        if (!room.name.startsWith('Grid:')) {
          print("Grid: Skipping non-Grid room: ${room.name}");
          continue;
        }

        // Handle different room types
        if (room.name.startsWith('Grid:Group:')) {
          // Process group rooms
          final parts = room.name.split(':');
          if (parts.length < 3) continue;

          final expirationStr = parts[2];
          final expirationTimestamp = int.tryParse(expirationStr);
          print("Grid: Group room expiration: $expirationTimestamp, current: $currentTimestamp");

          // Skip expired group rooms
          if (expirationTimestamp != null &&
              expirationTimestamp != 0 &&
              expirationTimestamp < currentTimestamp) {
            print("Grid: Skipping expired group room");
            continue;
          }
        } else if (!room.name.startsWith('Grid:Direct:')) {
          print("Grid: Skipping unknown Grid room type: ${room.name}");
          continue;
        }

        // Get joined members and log
        var joinedMembers = room
            .getParticipants()
            .where((member) => member.membership == Membership.join)
            .toList();
        print("Grid: Room has ${joinedMembers.length} joined members");

        if (!joinedMembers.any((member) => member.id == getMyUserId())) {
          print("Grid: Skipping room ${room.id} - I am not a joined member");
          continue;
        }

        if (joinedMembers.length > 1) {

          if (joinedMembers.length == 2 && room.name.startsWith('Grid:Direct:')) {
            final myUserId = getMyUserId();
            var otherUsers = joinedMembers.where((member) =>
            member.id != myUserId);
            var otherUser = otherUsers.first.id;
            final isSharing = await userService.isInSharingWindow(otherUser);
            if (!isSharing) {
              print("Grid: Skipping direct room ${room
                  .id} - not in sharing window with $otherUser");
              continue;
            } else {
              print("In sharing window");
            }
          }

          if (joinedMembers.length >= 2 && room.name.startsWith('Grid:Group:')) {

            final isSharing = await userService.isGroupInSharingWindow(room.id);
            if (!isSharing) {
              print("Grid: Skipping group room ${room
                  .id} - not in sharing window.");
              continue;
            } else {
              print("In sharing window");
            }
          }


          print("Grid: Sending location event to room ${room.id} / ${room.name}");
          sendLocationEvent(room.id, location);
          print("Grid: Location event sent successfully");
        } else {
          print("Grid: Skipping room ${room.id} - insufficient members");
        }

      } catch (e) {
        print('Error processing room ${room.name}: $e');
        continue;
      }
    }
  }

// Helper method to check if a room is expired
  bool isRoomExpired(String roomName) {
    try {
      if (!roomName.startsWith('Grid:Group:')) return true;

      final parts = roomName.split(':');
      if (parts.length < 3) return true;

      final expirationStr = parts[2];
      final expirationTimestamp = int.tryParse(expirationStr);

      if (expirationTimestamp == null) return true;
      if (expirationTimestamp == 0) return false; // 0 means no expiration

      final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expirationTimestamp < currentTimestamp;
    } catch (e) {
      return true; // If there's any error parsing, consider the room expired
    }
  }

  Future<bool> kickMemberFromRoom(String roomId, String userId) async {
    final room = client.getRoomById(roomId);
    if (room != null && room.canKick) {
      try {
        room.kick(userId);
      } catch (e) {
        print("Failed to remove member");
        return false;
      }
      return true;
    }
    return false;
  }

  Future<void> updateSingleRoom(String roomId) async {
    final room = client.getRoomById(roomId);
    if (room != null) {
      // Verify it's a valid room to send to (direct room or group)
      var joinedMembers = room
          .getParticipants()
          .where((member) => member.membership == Membership.join)
          .toList();

      if (joinedMembers.length >= 2) {  // Valid room with at least 2 members
        sendLocationEvent(roomId, currentLocation!);
      }
    }
  }

  Map<String, Map<String, String>> getUserDeviceKeys(String userId) {
    final userDeviceKeys = client.userDeviceKeys[userId]?.deviceKeys.values;
    Map<String, Map<String, String>> deviceKeysMap = {};

    if (userDeviceKeys != null) {
      for (final deviceKeyEntry in userDeviceKeys) {
        final deviceId = deviceKeyEntry.deviceId;
        if (deviceId != null) {
          deviceKeysMap[deviceId] = {
            "curve25519": deviceKeyEntry.keys['curve25519:$deviceId'] ?? "",
            "ed25519": deviceKeyEntry.keys['ed25519:$deviceId'] ?? ""
          };
        }
      }
    }
    return deviceKeysMap;
  }

  Future<void> updateAllUsersDeviceKeys() async {
    final rooms = client.rooms;
    rooms.forEach((room) async => {
      await updateUsersInRoomKeysStatus(room)
    });
  }

  Future<void> addTag(String roomId, String tag, {double? order}) async {
    try {
      print("Attempting to add tag '$tag' to room ID $roomId");
      await client.setRoomTag(client.userID!, roomId, tag, order: order);
      print("Tag added successfully.");
    } catch (e) {
      print("Failed to add tag: $e");
    }
  }


  Future<bool> userHasNewDeviceKeys(String userId, Map<String, dynamic> newKeys) async {
    final curKeys = await userKeysRepository.getKeysByUserId(userId);

    if (curKeys == null) {
      // Log or handle cases where no keys exist for the user
      print("No existing keys found. Inserting new keys.");
      await userKeysRepository.upsertKeys(userId, newKeys['curve25519Key'], newKeys['ed25519Key']);
      return false; // No need to alert, as these are the first keys
    }

    // Check for new keys
    for (final key in newKeys.keys) {
      if (!curKeys.containsKey(key) || curKeys[key] != newKeys[key]) {
        return true; // New or updated key found
      }
    }

    // No new keys
    return false;
  }

  String? getMyUserId() {
    return client.userID;
  }
  Future<void> updateUsersInRoomKeysStatus(Room room) async {
    final members = room.getParticipants().where((member) => member.membership == Membership.join);

    for (final member in members) {
      // Get all device keys for the user
      final userDeviceKeys = getUserDeviceKeys(member.id);

      for (final deviceId in userDeviceKeys.keys) {
        final deviceKeys = userDeviceKeys[deviceId]!; // Keys for a specific device

        // Fetch existing keys for the user
        final existingKeys = await userKeysRepository.getKeysByUserId(member.id);

        if (existingKeys == null) {
          // No existing keys, insert the current device's keys
          await userKeysRepository.upsertKeys(
            member.id,
            deviceKeys['curve25519']!,
            deviceKeys['ed25519']!,
          );
        } else {
          // Check if the user has new or updated keys
          final hasNewKeys = await userHasNewDeviceKeys(member.id, deviceKeys);

          if (hasNewKeys) {
            // Update approval status (if applicable)
            // Example: Add this to UserKeysRepository if needed
            // await userKeysRepository.updateApprovalStatus(member.id, false);

            // Insert new keys to update the record
            await userKeysRepository.upsertKeys(
              member.id,
              deviceKeys['curve25519']!,
              deviceKeys['ed25519']!,
            );
          }
        }
      }
    }
  }

  Future<void> setAvatar(MatrixFile? file) async {
    try {
      if (file == null) {
        // We send empty string to remove avatar due to Synapse behavior
        await client.setAvatarUrl(client.userID!, Uri.parse(''));
        return;
      }

      final uploadResp = await client.uploadContent(
        file.bytes,
        filename: file.name,
        contentType: file.mimeType,
      );

      await client.setAvatarUrl(client.userID!, uploadResp);
    } catch (e) {
      print('RoomService setAvatar error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDirectRooms() async {
    try {
      await client.sync();
      List<User> directUsers = [];
      Map<User, String> userRoomMap = {};

      for (var room in client.rooms) {
        final participants = await room.getParticipants();

        // Find the current user's membership in the room.
        final ownMembership = participants
            .firstWhere((user) => user.id == client.userID)
            .membership;

        // Only include rooms where the current user has joined.
        if (room.name.contains("Grid:Direct") && ownMembership == Membership.join) {
          try {
            // Find the other member in the room (the one you are chatting with).
            final otherMember = participants.firstWhere(
                  (user) => user.id != client.userID,
            );

            // Add this user to the direct users list and map them to the room.
            directUsers.add(otherMember);
            userRoomMap[otherMember] = room.id;
          } catch (e) {
            // Log if no other member is found.
            print('No other member found in room: ${room.id}');
            // TODO: may be causing issue with contacts screen
            await leaveRoom(room.id);
            print('Left room: ${room.id}');

          }
        }
      }

      return {
        "users": directUsers,
        "userRoomMap": userRoomMap,
      };
    } catch (e) {
      print("Error getting direct rooms: $e");
      return {
        "users": [],
        "userRoomMap": {},
      };
    }
  }
}
