import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:grid_frontend/utilities/utils.dart';

class GroupListItem extends StatelessWidget {
  final Room room;
  final bool isInvitation;
  final VoidCallback? onTap;  // Callback for tap events

  const GroupListItem({
    Key? key,
    required this.room,
    required this.isInvitation,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the name after the user ID, assuming format is "userID:actualGroupName"
    final groupName = room.name.split('-').last;
    final memberCount = room.getParticipants().where((m) => m.membership == Membership.join).length;
    String subtitleText = isInvitation ? 'Group Invite Request' : '$memberCount members';

    return ListTile(
      leading: CircleAvatar(
        child: Text(groupName.isNotEmpty ? groupName[0].toUpperCase() : '?'),
        backgroundColor: generateColorFromUsername(groupName),
      ),
      title: Text(groupName),
      subtitle: Text(subtitleText),
      onTap: onTap,
    );
  }
}
