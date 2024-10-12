import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'package:grid_frontend/widgets/group_list_item.dart';
import 'package:grid_frontend/widgets/group_invitation_modal.dart';  // Assuming you have this modal created
import 'package:grid_frontend/screens/group_settings/group_settings_page.dart';
import 'package:grid_frontend/widgets/custom_search_bar.dart';
import 'package:grid_frontend/utilities/utils.dart';

class GroupsList extends StatefulWidget {
  final List<Room> groupsRooms;
  final List<Room> groupInvitations;
  final TextEditingController searchController;
  final Client client;
  final VoidCallback refreshCallback;
  final String currentUserId;  // Make sure this parameter is included if needed

  GroupsList({
    required this.groupsRooms,
    required this.groupInvitations,
    required this.searchController,
    required this.client,
    required this.refreshCallback,
    required this.currentUserId,  // Ensure this is here if you're passing it from HomeTab
  });

  @override
  _GroupsListState createState() => _GroupsListState();
}


class _GroupsListState extends State<GroupsList> {
  late List<Room> _displayedGroupsRooms;

  @override
  void initState() {
    super.initState();
    _displayedGroupsRooms = [...widget.groupInvitations, ...widget.groupsRooms];
    widget.searchController.addListener(_filterGroups);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_filterGroups);
    super.dispose();
  }

  void _filterGroups() {
    final query = widget.searchController.text.toLowerCase();
    setState(() {
      _displayedGroupsRooms = query.isEmpty
          ? [...widget.groupInvitations, ...widget.groupsRooms]
          : [...widget.groupInvitations, ...widget.groupsRooms].where((room) => room.name.toLowerCase().contains(query)).toList();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomSearchBar(controller: widget.searchController),
        Expanded(
          child: ListView.builder(
            itemCount: _displayedGroupsRooms.length,
            itemBuilder: (context, index) {
              final room = _displayedGroupsRooms[index];
              bool isInvitation = widget.groupInvitations.contains(room);
              return GroupListItem(
                room: room,
                isInvitation: isInvitation,
                onTap: () {
                  if (isInvitation) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) => GroupInvitationModal(room: room),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupSettingsPage(room: room),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
