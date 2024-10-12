import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:grid_frontend/screens/friend_settings/friend_settings_page.dart';
import 'package:grid_frontend/widgets/custom_search_bar.dart';
import 'package:grid_frontend/widgets/friend_request_modal.dart';
import 'package:grid_frontend/widgets/group_invitation_modal.dart';
import 'package:grid_frontend/screens/group_settings/group_settings_page.dart';
import 'package:grid_frontend/handlers/friends_list_handler.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:grid_frontend/widgets/triangle_avatars.dart'; // Import TriangleAvatars
import 'dart:async';

enum FilterOption { none, friends, groups, invites }

class FriendsList extends StatefulWidget {
  final TextEditingController searchController;
  final Client client;
  final VoidCallback refreshCallback;

  FriendsList({
    required this.searchController,
    required this.client,
    required this.refreshCallback,
  });

  @override
  _FriendsListState createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  List<Room> _displayedRooms = [];
  late FriendsListHandler _friendsListHandler;
  late List<Room> friendsRooms;
  late List<Room> groupsRooms;
  late List<Room> friendInvitations;
  late List<Room> groupInvitations;
  FilterOption _selectedFilter = FilterOption.none;

  @override
  void initState() {
    super.initState();
    _friendsListHandler = FriendsListHandler(client: widget.client);
    widget.searchController.addListener(_filterRooms);
    _fetchAndDisplayRooms();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_filterRooms);
    super.dispose();
  }

  Future<void> _fetchAndDisplayRooms() async {
    final roomsMap = await _friendsListHandler.fetchRooms(context);

    setState(() {
      friendsRooms = roomsMap['friendsRooms'] ?? [];
      groupsRooms = roomsMap['groupsRooms'] ?? [];
      friendInvitations = roomsMap['friendInvitations'] ?? [];
      groupInvitations = roomsMap['groupInvitations'] ?? [];

      _updateDisplayedRooms();
    });
  }

  void _filterRooms() async {
    final query = widget.searchController.text.toLowerCase();

    setState(() {
      _updateDisplayedRooms(query: query);
    });
  }

  void _updateDisplayedRooms({String query = ''}) {
    List<Room> filteredRooms = [];

    switch (_selectedFilter) {
      case FilterOption.friends:
        filteredRooms = friendsRooms;
        break;
      case FilterOption.groups:
        filteredRooms = groupsRooms;
        break;
      case FilterOption.invites:
        filteredRooms = [...friendInvitations, ...groupInvitations];
        break;
      case FilterOption.none:
      default:
        filteredRooms = [...friendsRooms, ...groupsRooms, ...friendInvitations, ...groupInvitations];
        break;
    }

    _displayedRooms = filteredRooms.where((room) {
      return room.name?.toLowerCase().contains(query) ?? false;
    }).toList();
  }

  String _extractGroupName(String fullName) {
    final startIndex = fullName.indexOf('(');
    final endIndex = fullName.indexOf(')');
    if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
      return fullName.substring(startIndex + 1, endIndex);
    }
    return fullName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        CustomSearchBar(controller: widget.searchController),
        _buildFilterOptions(),
        Expanded(
          child: ListView.builder(
            itemCount: _displayedRooms.length,
            itemBuilder: (context, index) {
              final room = _displayedRooms[index];
              final participants = room.getParticipants();

              // Ensure that the room is a direct chat with exactly two participants
              final isDirectChatWithTwoParticipants = room.isDirectChat && participants.length == 2;

              User? otherMember;
              if (isDirectChatWithTwoParticipants) {
                final otherMemberIndex = participants.indexWhere((m) => m.id != widget.client.userID);

                // Skip rendering if the other participant is not found
                if (otherMemberIndex == -1) {
                  return SizedBox.shrink();
                }

                otherMember = participants[otherMemberIndex];
              }

              bool isFriendRequest = friendInvitations.contains(room);
              bool isGroupRequest = groupInvitations.contains(room);
              String displayName = room.isDirectChat
                  ? (otherMember?.displayName ?? otherMember?.id ?? 'Unknown User')
                  : _extractGroupName(room.name ?? 'Group');

              String label = isFriendRequest
                  ? 'Friend Request'
                  : isGroupRequest
                  ? 'Group Invitation'
                  : room.isDirectChat
                  ? 'Friend'
                  : 'Group';

              return FutureBuilder<String>(
                future: room.isDirectChat
                    ? _friendsListHandler.getLastSeenTime(room, widget.client)
                    : Future.value(''),
                builder: (context, snapshot) {
                  String lastSeen = snapshot.data ?? '';
                  return ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: colorScheme.onBackground, // Adjust based on theme
                          ),
                        ),
                        if (!isFriendRequest && !isGroupRequest)
                          Text(
                            room.isDirectChat ? lastSeen : '${participants.length} members',
                            style: TextStyle(
                              color: colorScheme.onSurface, // Adjust based on theme
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.onSurface, // Adjust based on theme
                      ),
                    ),
                    leading: room.isDirectChat
                        ? RandomAvatar(
                      displayName,
                      height: 40,
                      width: 40,
                    )
                        : TriangleAvatars(
                        userIds: participants
                            .map((m) => m.id.split(":").first.replaceFirst('@', ''))
                            .toList()),
                    onTap: () {
                      if (isFriendRequest) {
                        _handleFriendRequestTap(room, displayName);
                      } else if (isGroupRequest) {
                        _handleGroupInvitationTap(room, displayName);
                      } else if (room.isDirectChat) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => FriendSettingsPage(user: otherMember!)),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => GroupSettingsPage(roomId: room.id)),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterOptions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFilterOptionButton('People', FilterOption.friends, colorScheme),
          _buildFilterOptionButton('Groups', FilterOption.groups, colorScheme),
          _buildFilterOptionButton('Invites', FilterOption.invites, colorScheme),
        ],
      ),
    );
  }

  Widget _buildFilterOptionButton(String label, FilterOption option, ColorScheme colorScheme) {
    final isSelected = _selectedFilter == option;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedFilter = isSelected ? FilterOption.none : option;
          _updateDisplayedRooms();
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? colorScheme.primary : colorScheme.background,
        foregroundColor: isSelected ? colorScheme.onPrimary : colorScheme.onBackground,
      ),
      child: Text(label),
    );
  }

  void _handleFriendRequestTap(Room room, String displayName) {
    final otherMember = room.getParticipants().firstWhere((m) => m.id != widget.client.userID);
    showDialog(
      context: context,
      builder: (context) => FriendRequestModal(
        userId: otherMember.id,
        displayName: displayName,
        onResponse: (accept) async {
          Navigator.of(context).pop();
          if (accept) {
            try {
              await widget.client.getRoomById(room.id)?.join();
              widget.refreshCallback(); // Refresh the room list after accepting the request
            } catch (e) {
              // Handle error if necessary
            }
          } else {
            try {
              await widget.client.getRoomById(room.id)?.leave();
              widget.refreshCallback(); // Refresh the room list after rejecting the request
            } catch (e) {
              // Handle error if necessary
            }
          }
        },
      ),
    );
  }

  void _handleGroupInvitationTap(Room room, String displayName) {
    showDialog(
      context: context,
      builder: (context) => GroupInvitationModal(
        room: room,
        groupName: displayName,
        roomId: room.id,
        refreshCallback: () async {
          widget.refreshCallback();
        },
      ),
    );
  }
}
