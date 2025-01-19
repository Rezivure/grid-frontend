import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grid_frontend/repositories/location_repository.dart';
import 'package:matrix/matrix.dart';
import 'package:grid_frontend/services/message_processor.dart';
import 'package:grid_frontend/services/room_service.dart';
import 'package:grid_frontend/repositories/room_repository.dart';
import 'package:grid_frontend/repositories/user_repository.dart';
import 'package:grid_frontend/models/room.dart' as grid_room;
import 'package:grid_frontend/utilities/utils.dart';
import 'package:grid_frontend/models/grid_user.dart' as grid_user;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grid_frontend/providers/user_location_provider.dart';


import '../blocs/groups/groups_bloc.dart';
import '../blocs/groups/groups_event.dart';

import '../blocs/contacts/contacts_bloc.dart';
import '../blocs/contacts/contacts_event.dart';

import '../blocs/map/map_bloc.dart';
import '../blocs/map/map_event.dart';

import '../models/pending_message.dart';



class SyncManager with ChangeNotifier {
  final Client client;
  final RoomService roomService;
  final MessageProcessor messageProcessor;
  final RoomRepository roomRepository;
  final UserRepository userRepository;
  final LocationRepository locationRepository;
  final UserLocationProvider userLocationProvider;
  final MapBloc mapBloc;
  final ContactsBloc contactsBloc;
  final GroupsBloc groupsBloc;
  final List<PendingMessage> _pendingMessages = [];
  bool _isActive = true;

  bool _isSyncing = false;
  final List<Map<String, dynamic>> _invites = [];
  final Map<String, List<Map<String, dynamic>>> _roomMessages = {};
  bool _isInitialized = false;
  String? _sinceToken;


  SyncManager(
      this.client,
      this.messageProcessor,
      this.roomRepository,
      this.userRepository,
      this.roomService,
      this.mapBloc,
      this.contactsBloc,
      this.locationRepository,
      this.groupsBloc,
      this.userLocationProvider
      );

  List<Map<String, dynamic>> get invites => List.unmodifiable(_invites);
  Map<String, List<Map<String, dynamic>>> get roomMessages => Map.unmodifiable(_roomMessages);
  int get totalInvites => _invites.length;

  Future<void> _loadSinceToken() async {
    final prefs = await SharedPreferences.getInstance();
    _sinceToken = prefs.getString('syncSinceToken');
    log('[SyncManager] Loaded since token: $_sinceToken');
  }

  Future<void> _saveSinceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('syncSinceToken', token);
    log('[SyncManager] Saved since token: $token');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    log("Initializing Sync Manager...");
    try {
      await _loadSinceToken();
      await roomService.cleanRooms();

      final response = await client.sync(
        since: _sinceToken,
        fullState: _sinceToken == null,
        timeout: 15000,
      );

      await _saveSinceToken(response.nextBatch);
      _sinceToken = response.nextBatch;
    
      _processInitialSync(response);
      await startSync();
      _isInitialized = true; // Only set after successful completion
    } catch (e) {
      log("Error during initialization", error: e);
      // Maybe add some retry logic here
    }
  }

  Future<void> startSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    client.sync(fullState: true);


    client.onSync.stream.listen((SyncUpdate syncUpdate) {
      // Process invites
      syncUpdate.rooms?.invite?.forEach((roomId, inviteUpdate) {
        _processInvite(roomId, inviteUpdate);
      });

      // Process room messages and joins
      syncUpdate.rooms?.join?.forEach((roomId, joinedRoomUpdate) {
        log("Got join update for room: $roomId");
        _processRoomMessages(roomId, joinedRoomUpdate);

        // Check if there are any state events before processing
        if ((joinedRoomUpdate.state ?? []).isNotEmpty) {
          log("Found state events, processing join");
          _processRoomJoin(roomId, joinedRoomUpdate);
        }
      });

      // Process room departures and kicks
      syncUpdate.rooms?.leave?.forEach((roomId, leftRoomUpdate) {
        _processRoomLeaveOrKick(roomId, leftRoomUpdate);
      });
    });
  }

  void handleAppLifecycleState(bool isActive) {
    _isActive = isActive;
    if (isActive) {
      if (_pendingMessages.isNotEmpty) {
        _processPendingMessages();
      }
      // full refresh as well
      client.sync(fullState: true, timeout: 10000).then((_) {
        mapBloc.add(MapLoadUserLocations()); // Refresh locations
      }).catchError((e) {
        log('Error during resume sync', error: e);
      });
    }
  }

  Future<void> stopSync() async {
    if (!_isSyncing) return;

    _isSyncing = false;
    client.abortSync();
  }

  void _processInvite(String roomId, InvitedRoomUpdate inviteUpdate) {
    if (!_inviteExists(roomId)) {
      final inviter = _extractInviter(inviteUpdate);
      final roomName = _extractRoomName(inviteUpdate) ?? 'Unnamed Room';

      final inviteData = {
        'roomId': roomId,
        'inviter': inviter,
        'roomName': roomName,
        'inviteState': inviteUpdate.inviteState,
      };

      _invites.add(inviteData);
      notifyListeners();
    }
  }

  Future<void> clearAllState() async {
    _invites.clear();
    _roomMessages.clear();
    _pendingMessages.clear();
    _isInitialized = false;
    _isSyncing = false;

    // Stop syncing
    await stopSync();
    // Notify listeners of the changes
    notifyListeners();
  }

  Future<void> _processRoomLeave(String roomId, LeftRoomUpdate leftRoomUpdate) async {
    try {
      final room = await roomRepository.getRoomById(roomId);

      if (room != null && !room.isGroup) {
        final participants = await roomRepository.getRoomParticipants(roomId);
        final otherUserId = participants.firstWhere(
              (id) => id != client.userID,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          log("Processing complete removal for user: $otherUserId");

          // Check if user exists in any other rooms
          final userRooms = await roomRepository.getUserRooms(otherUserId);

          // Clean up database
          await userRepository.removeContact(otherUserId);
          await roomRepository.deleteRoom(roomId);

          // If user isn't in any other rooms, clean up all their data
          if (userRooms.length <= 1) {  // <= 1 because current room is still counted
            log("User not in any other rooms, removing completely");
            await locationRepository.deleteUserLocations(otherUserId);
            await userRepository.deleteUser(otherUserId);
          }

          // Update UI
          mapBloc.add(RemoveUserLocation(otherUserId));
          contactsBloc.add(RefreshContacts());

          log('Completed cleanup for user $otherUserId');
        }
      }
    } catch (e) {
      log('Error processing room leave', error: e);
    }
  }

  Future<void> _handleKickedFromRoom(grid_room.Room room) async {
    try {
      final roomId = room.roomId;
      final participants = room.members;

      // First, remove any UserRelationships for this room
      for (final participantId in participants) {
        await userRepository.removeUserRelationship(participantId, roomId);
      }

      // Remove all RoomParticipants
      await roomRepository.removeAllParticipants(roomId);

      // Delete the room itself
      await roomRepository.deleteRoom(roomId);

      // For each participant, check if they need complete cleanup
      for (final participantId in participants) {
        final userRooms = await roomRepository.getUserRooms(participantId);
        final hasDirectRoom = await userRepository.getDirectRoomForContact(participantId);

        if (userRooms.isEmpty && hasDirectRoom == null) {
          log("Cleaning up user completely: $participantId");
          await locationRepository.deleteUserLocations(participantId);
          await userRepository.deleteUser(participantId);
          userLocationProvider.removeUserLocation(participantId);
          mapBloc.add(RemoveUserLocation(participantId));
        }
      }

      // Update UI with staggered refreshes to ensure everything updates
      groupsBloc.add(RefreshGroups());
      groupsBloc.add(LoadGroups());
      mapBloc.add(MapLoadUserLocations());

      // Force additional updates after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        groupsBloc.add(RefreshGroups());
        groupsBloc.add(LoadGroups());
      });

      Future.delayed(const Duration(seconds: 1), () {
        groupsBloc.add(RefreshGroups());
        groupsBloc.add(LoadGroups());
        mapBloc.add(MapLoadUserLocations());
      });

      log("Completed kick cleanup for room: $roomId");
    } catch (e) {
      log('Error handling kicked from room', error: e);
    }
  }

  Future<void> _processRoomLeaveOrKick(String roomId, LeftRoomUpdate leftRoomUpdate) async {
    try {
      // First check if this was a kick by examining state events
      bool wasKicked = false;
      String? kickedBy;

      for (var event in (leftRoomUpdate.timeline?.events ?? [])) {
        if (event.type == 'm.room.member' &&
            event.stateKey == client.userID &&
            event.content['membership'] == 'leave' &&
            event.senderId != client.userID) {
          wasKicked = true;
          kickedBy = event.senderId;
          break;
        }
      }

      final room = await roomRepository.getRoomById(roomId);
      if (room == null) return;

      if (wasKicked) {
        log("User was kicked from room $roomId by $kickedBy");

        // Immediately clear from local storage
        await roomRepository.deleteRoom(roomId);
        await roomRepository.removeAllParticipants(roomId);

        // Then do full cleanup
        await _handleKickedFromRoom(room);

        // Force UI refresh
        groupsBloc.add(RefreshGroups());
        groupsBloc.add(LoadGroups());
      } else {
        // Handle normal leave/departure
        await _processRoomLeave(roomId, leftRoomUpdate);
      }
    } catch (e) {
      log('Error processing room leave/kick', error: e);

      // Even if we get an error, try to clean up local data
      try {
        await roomRepository.deleteRoom(roomId);
        await roomRepository.removeAllParticipants(roomId);
        groupsBloc.add(RefreshGroups());
        groupsBloc.add(LoadGroups());
      } catch (cleanupError) {
        log('Error during emergency cleanup', error: cleanupError);
      }
    }
  }

  void _processRoomMessages(String roomId, JoinedRoomUpdate joinedRoomUpdate) {
    final timelineEvents = joinedRoomUpdate.timeline?.events ?? [];
    for (var event in timelineEvents) {
      if (!_isActive) {
        // Queue message if app is in background
        _pendingMessages.add(PendingMessage(
          roomId: roomId,
          eventId: event.eventId,
          event: event,
        ));
        continue;
      }

      messageProcessor.processEvent(roomId, event).then((message) {
        if (message != null) {
          _roomMessages.putIfAbsent(roomId, () => []).add(message);
          notifyListeners();
        }
      }).catchError((e) {
        if (e is PlatformException && e.code == '-25308') {
          // Queue message if we get keychain access error
          _pendingMessages.add(PendingMessage(
            roomId: roomId,
            eventId: event.eventId,
            event: event,
          ));
        } else {
          log("Error processing event ${event.eventId}", error: e);
        }
      });
    }
  }

  Future<void> _processPendingMessages() async {
    if (_pendingMessages.isEmpty) return;

    log("Processing ${_pendingMessages.length} pending messages");

    final messagesToProcess = List<PendingMessage>.from(_pendingMessages);
    _pendingMessages.clear();

    for (var pendingMessage in messagesToProcess) {
      await messageProcessor.processEvent(
        pendingMessage.roomId,
        pendingMessage.event,
      ).then((message) {
        if (message != null) {
          _roomMessages.putIfAbsent(pendingMessage.roomId, () => []).add(message);
          notifyListeners();
        }
      }).catchError((e) {
        log("Error processing pending event ${pendingMessage.eventId}", error: e);
      });
    }
  }

  Future<void> handleNewGroupCreation(String roomId) async {
    log("SyncManager: Handling new group creation for room $roomId");

    try {
      final matrixRoom = client.getRoomById(roomId);
      if (matrixRoom != null) {
        // First sync to ensure we have latest state
        await client.sync(timeout: 10000);

        // Process the room and wait for completion
        await initialProcessRoom(matrixRoom);

        // Verify room was processed
        final processedRoom = await roomRepository.getRoomById(roomId);
        log("Room processed status: ${processedRoom != null}");

        // Force immediate refresh
        groupsBloc.add(RefreshGroups());

        // Staggered refreshes with verification
        Future.delayed(const Duration(milliseconds: 500), () async {
          final room = await roomRepository.getRoomById(roomId);
          if (room != null) {
            groupsBloc.add(LoadGroups());
            groupsBloc.add(RefreshGroups());
          }
        });

        Future.delayed(const Duration(seconds: 1), () async {
          final room = await roomRepository.getRoomById(roomId);
          if (room != null) {
            groupsBloc.add(LoadGroups());
            groupsBloc.add(RefreshGroups());
          }
        });
      }
    } catch (e) {
      log("Error in handleNewGroupCreation", error: e);
    }
  }

  Future<void> _processRoomJoin(String roomId, JoinedRoomUpdate joinedRoomUpdate) async {
    try {
      log("Processing room join for room: $roomId");
      final stateEvents = joinedRoomUpdate.state ?? [];
      log("Found ${stateEvents.length} state events");

      // First pass: Check if this is an initial room join
      bool isInitialJoin = false;
      bool isGroupRoom = false;

      final room = await roomRepository.getRoomById(roomId);
      isInitialJoin = room == null;  // Keep this for immediate contact inserts

      // Also check for actual join events (e.g., accepting invite)
      for (var event in stateEvents) {
        if (event.type == 'm.room.member') {
          final membershipStatus = event.content['membership'] as String?;
          final prevMembership = event.prevContent?['membership'] as String?;

          // Consider it a join if:
          // 1. New member joining (membership = join, prev != join)
          // 2. NOT someone being kicked (prev = join, membership = leave)
          if (membershipStatus == 'join' &&
              prevMembership != 'join' &&
              !(prevMembership == 'join' && membershipStatus == 'leave')) {
            isInitialJoin = true;
            break;
          }
        }
      }

      // If it's an initial join, process the full room
      if (isInitialJoin) {
        log("Processing initial room join");
        final matrixRoom = client.getRoomById(roomId);
        if (matrixRoom != null) {
          final room = await roomRepository.getRoomById(roomId);
          isGroupRoom = room?.isGroup ?? false;

          await initialProcessRoom(matrixRoom);

          // Update appropriate bloc based on room type
          if (isGroupRoom) {
            groupsBloc.add(RefreshGroups());
          } else {
            contactsBloc.add(RefreshContacts());
          }

          mapBloc.add(MapLoadUserLocations());
        }
        return;
      }

      // Second pass: Process individual state events
      for (var event in stateEvents) {
        log("Processing event type: ${event.type}");
        if (event.type == 'm.room.member') {
          // Don't process member events for kicked users
          final membershipStatus = event.content['membership'] as String?;
          final prevMembership = event.prevContent?['membership'] as String?;

          if (!(prevMembership == 'join' && membershipStatus == 'leave')) {
            await _processMemberStateEvent(roomId, event);
          }
        } else {
          // Process other state events through message processor
          await messageProcessor.processEvent(roomId, event).then((message) {
            if (message != null) {
              _roomMessages.putIfAbsent(roomId, () => []).add(message);
              notifyListeners();
            }
          });
        }
      }
    } catch (e) {
      log('Error processing room join', error: e);
    }
  }

  Future<void> _processMemberStateEvent(String roomId, MatrixEvent event) async {
    log("Processing member event: ${event.stateKey} with content: ${event.content}");

    final room = await roomRepository.getRoomById(roomId);
    if (room == null) return;

    if (room.isGroup) {
      final membershipStatus = event.content['membership'] as String? ?? 'invited';

      if (event.stateKey != null) {
        await userRepository.updateMembershipStatus(
            event.stateKey!,
            roomId,
            membershipStatus
        );

        groupsBloc.add(UpdateGroup(roomId));

        if (membershipStatus == 'invite') {
          try {
            final profileInfo = await client.getUserProfile(event.stateKey!);
            final gridUser = grid_user.GridUser(
              userId: event.stateKey!,
              displayName: profileInfo.displayname,
              avatarUrl: profileInfo.avatarUrl?.toString(),
              lastSeen: DateTime.now().toIso8601String(),
              profileStatus: "",
            );
            await userRepository.insertUser(gridUser);
          } catch (e) {
            log('Error fetching profile for invited user ${event.stateKey}', error: e);
          }
        }
      }
    }

    if (event.stateKey != null) {
      final membershipStatus = event.content['membership'] as String?;

      if (membershipStatus == 'join') {
        try {
          // Update or create user profile
          final profileInfo = await client.getUserProfile(event.stateKey!);
          final gridUser = grid_user.GridUser(
            userId: event.stateKey!,
            displayName: profileInfo.displayname,
            avatarUrl: profileInfo.avatarUrl?.toString(),
            lastSeen: DateTime.now().toIso8601String(),
            profileStatus: "",
          );
          await userRepository.insertUser(gridUser);

          // Update relationship
          await userRepository.insertUserRelationship(
            event.stateKey!,
            roomId,
            !room.isGroup, // isDirect
          );

          // Update UI based on room type
          if (room.isGroup) {
            groupsBloc.add(UpdateGroup(roomId));
          } else {
            log("Direct room join detected, refreshing contacts");
            contactsBloc.add(RefreshContacts());
          }
        } catch (e) {
          log('Error updating user profile for ${event.stateKey}', error: e);
        }
      } else if (membershipStatus == 'leave') {
        await _handleMemberLeave(roomId, event.stateKey);
      }
    }
  }

  Future<void> _handleMemberLeave(String roomId, String? userId) async {
    if (userId == null || userId == client.userID) return;

    log("Processing leave for user: $userId in room: $roomId");
    final room = await roomRepository.getRoomById(roomId);

    if (room != null) {
      if (room.isGroup) {
        try {
          // Remove the user from room members list
          final updatedMembers = room.members.where((id) => id != userId).toList();
          final updatedRoom = grid_room.Room(
            roomId: room.roomId,
            name: room.name,
            isGroup: room.isGroup,
            lastActivity: DateTime.now().toIso8601String(),
            avatarUrl: room.avatarUrl,
            members: updatedMembers,
            expirationTimestamp: room.expirationTimestamp,
          );

          // Update the room with new member list
          await roomRepository.updateRoom(updatedRoom);

          // Remove all relationships for this user in this room
          await userRepository.removeUserRelationship(userId, roomId);
          await roomRepository.removeRoomParticipant(roomId, userId);

          // Update membership status to 'leave'
          await userRepository.updateMembershipStatus(userId, roomId, 'leave');

          // Check if user should be completely cleaned up
          final userRooms = await roomRepository.getUserRooms(userId);
          final hasDirectRoom = await userRepository.getDirectRoomForContact(userId);

          if (userRooms.isEmpty && hasDirectRoom == null) {
            log("User not in any other rooms/contacts, cleaning up completely");
            await locationRepository.deleteUserLocations(userId);
            await userRepository.deleteUser(userId);
            mapBloc.add(RemoveUserLocation(userId));
          }

          // Update UI with staggered refreshes
          groupsBloc.add(LoadGroupMembers(roomId));
          groupsBloc.add(UpdateGroup(roomId));
          groupsBloc.add(RefreshGroups());

          // Additional delayed updates to ensure sync
          Future.delayed(const Duration(milliseconds: 500), () {
            groupsBloc.add(LoadGroups());
            groupsBloc.add(LoadGroupMembers(roomId));
          });

        } catch (e) {
          log('Error processing group member leave', error: e);
        }
      } else {
        // Handle direct room cleanup
        await userRepository.removeContact(userId);
        await roomRepository.deleteRoom(roomId);

        final userRooms = await roomRepository.getUserRooms(userId);
        if (userRooms.isEmpty) {
          await locationRepository.deleteUserLocations(userId);
          await userRepository.deleteUser(userId);
          mapBloc.add(RemoveUserLocation(userId));
        }

        contactsBloc.add(RefreshContacts());
      }
    }
  }

  void _processInitialSync(SyncUpdate response) {
    // Update Invites
    response.rooms?.invite?.forEach((roomId, inviteUpdate) {
      _processInvite(roomId, inviteUpdate);
    });

    // If needed, process the joined/left rooms in the response
    response.rooms?.join?.forEach((roomId, joinedRoomUpdate) {
      _processRoomMessages(roomId, joinedRoomUpdate);
      if ((joinedRoomUpdate.state ?? []).isNotEmpty) {
        _processRoomJoin(roomId, joinedRoomUpdate);
      }
    });
    response.rooms?.leave?.forEach((roomId, leftRoomUpdate) {
      _processRoomLeaveOrKick(roomId, leftRoomUpdate);
    });

    // Finally, process the full client.rooms if you like
    for (var room in client.rooms) {
      initialProcessRoom(room);
    }

    // Refresh contacts
    contactsBloc.add(LoadContacts());

    notifyListeners();
  }

  Future<void> initialProcessRoom(Room room) async {
    // Check if the room already exists
    final existingRoom = await roomRepository.getRoomById(room.id);

    final isDirect = isDirectRoom(room.name );
    final customRoom = grid_room.Room(
      roomId: room.id,
      name: room.name,
      isGroup: !isDirect,
      lastActivity: DateTime.now().toIso8601String(),
      avatarUrl: room.avatar?.toString(),
      members: room.getParticipants().map((p) => p.id).toList(),
      expirationTimestamp: extractExpirationTimestamp(room.name),
    );

    if (existingRoom == null) {
      // Insert new room
      await roomRepository.insertRoom(customRoom);
      log('Inserted new room: ${room.id}');
    } else {
      // Update existing room
      await roomRepository.updateRoom(customRoom);
      log('Updated existing room: ${room.id}');
    }

    // Sync participants
    final currentParticipants = customRoom.members;
    final existingParticipants = await roomRepository.getRoomParticipants(room.id);

    for (var participantId in currentParticipants) {
      try {
        // Fetch participant details using client.getUserProfile
        final profileInfo = await client.getUserProfile(participantId);

        // Create or update the user in the database
        final gridUser = grid_user.GridUser(
          userId: participantId,
          displayName: profileInfo.displayname,
          avatarUrl: profileInfo.avatarUrl?.toString(),
          lastSeen: DateTime.now().toIso8601String(),
          profileStatus: "", // Future implementations
        );

        await userRepository.insertUser(gridUser);

        String? membershipStatus;
        if (!isDirect) {
          membershipStatus = await roomService.getUserRoomMembership(room.id, participantId) ?? 'invited';
        }

        await userRepository.insertUserRelationship(
            participantId,
            room.id,
            isDirect,
            membershipStatus: !isDirect ? membershipStatus : null
        );

        final customRoom = await roomRepository.getRoomById(room.id);
        if (customRoom?.isGroup ?? false) {
          log('Updating group in bloc: ${room.id}');
          groupsBloc.add(UpdateGroup(room.id));
        }
        log('Processed user $participantId in room ${room.id}');
      } catch (e) {
        log('Error fetching profile for user $participantId', error: e);
      }
    }

    // Remove participants who are no longer in the room
    for (var participant in existingParticipants) {
      if (!currentParticipants.contains(participant)) {
        await roomRepository.removeRoomParticipant(room.id, participant);
        log('Removed participant $participant from room ${room.id}');
      }
    }
  }

  Future<void> acceptInviteAndSync(String roomId) async {
    try {
      // Join the room
      final didJoin = await roomService.acceptInvitation(roomId);

      if (didJoin) {
        log('Successfully joined room $roomId');

        // Process the room to ensure database updates
        await roomService.updateSingleRoom(roomId);
        final room = client.getRoomById(roomId);
        if (room != null) {
          await initialProcessRoom(room);
        }

        // Trigger a full client sync to fetch all updates
        await client.sync(timeout: 10000);
        log('Sync completed for room $roomId');
      } else {
        throw Exception('Failed to join room');
      }
      // Remove invite since excepted
      removeInvite(roomId);
    } catch (e) {
      log('Error during room join and sync', error: e);
      rethrow; // Re-throw for error handling in calling code
    }
  }



  String _extractInviter(InvitedRoomUpdate inviteUpdate) {
    final inviteState = inviteUpdate.inviteState;
    if (inviteState != null) {
      for (var event in inviteState) {
        if (event.type == 'm.room.member' &&
            event.stateKey == client.userID &&
            event.content['membership'] == 'invite') {
          return event.senderId;
        }
      }
    }
    return 'Unknown';
  }

  String? _extractRoomName(InvitedRoomUpdate inviteUpdate) {
    final inviteState = inviteUpdate.inviteState;
    if (inviteState != null) {
      for (var event in inviteState) {
        if (event.type == 'm.room.name') {
          return event.content['name'] as String?;
        }
      }
    }
    return null;
  }

  bool _inviteExists(String roomId) {
    return _invites.any((invite) => invite['roomId'] == roomId);
  }

  void clearInvites() {
    _invites.clear();
    notifyListeners();
  }

  void clearRoomMessages(String roomId) {
    _roomMessages.remove(roomId);
    notifyListeners();
  }

  void removeInvite(String roomId) {
    _invites.removeWhere((invite) => invite['roomId'] == roomId);
    notifyListeners();
  }

  void clearAllRoomMessages() {
    _roomMessages.clear();
    notifyListeners();
  }

  bool _messageExists(String roomId, String? eventId) {
    final roomMessages = _roomMessages[roomId] ?? [];
    return roomMessages.any((message) => message['eventId'] == eventId);
  }
}
