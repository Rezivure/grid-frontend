import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:grid_frontend/widgets/triangle_avatars.dart';
import 'package:grid_frontend/widgets/friend_request_modal.dart';
import 'package:grid_frontend/widgets/group_invitation_modal.dart';

class InvitesSubscreen extends StatefulWidget {
  final ScrollController scrollController;
  final Future<void> Function() onInviteHandled; // Callback to handle invite

  InvitesSubscreen({
    required this.scrollController,
    required this.onInviteHandled, // Receive the callback
  });

  @override
  _InvitesSubscreenState createState() => _InvitesSubscreenState();
}

class _InvitesSubscreenState extends State<InvitesSubscreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(  // Ensure the content is expandable
          child: FutureBuilder<List<Map<String, String>>>(
            future: Provider.of<RoomProvider>(context, listen: false).getInvites(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error loading invites'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return ListView(
                  controller: widget.scrollController,
                  children: [Center(child: Text('No invitations found'))],
                );
              } else {
                final invites = snapshot.data!;

                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: invites.length,
                  padding: EdgeInsets.only(top: 8.0),
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    final roomId = invite['roomId'] ?? 'Unknown';
                    final inviterId = invite['inviter'] ?? 'Unknown';
                    final roomName = invite['roomName'] ?? 'Unnamed Room';
                    final type = invite['type'] ?? 'Unknown';
                    final isDirectInvite = roomName.contains("Grid:Direct");
                    var expiration = -1;
                    var groupName = "";
                    if (!isDirectInvite) {
                      // Split the roomName by ':' and get the third part (index 2)
                      var parts = roomName.split(':');
                      if (parts.length > 2) {
                        groupName = parts[3]; // This will give you the 'Test' part
                        expiration = int.parse(parts[2]);
                        print(expiration);
                      }
                    }

                    final inviterUsername = inviterId.split(":").first.replaceFirst('@', '');

                    return Column(
                      children: [
                        ListTile(
                          leading: RandomAvatar(inviterUsername, height: 60, width: 60),
                          title: Text(
                            inviterUsername, // Display inviter's username
                            style: TextStyle(color: colorScheme.onBackground),
                          ),
                          subtitle: Text(
                            isDirectInvite
                                ? '@$inviterUsername wants to connect with you.' // Direct invite message
                                : '@$inviterUsername wants you to join their group.', // Group invite message
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            _handleInviteTap(context, roomId, roomName, inviterId, isDirectInvite, groupName, expiration);
                          },
                        ),
                        Divider(
                          thickness: 1,
                          color: colorScheme.onSurface.withOpacity(0.1),
                          indent: 20,
                          endIndent: 20,
                        ),
                      ],
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }

  void _handleInviteTap(BuildContext context, String roomId, String roomName, String inviterId, bool isDirectInvite, String groupName, int expiration) {
    if (isDirectInvite) {
      showDialog(
        context: context,
        builder: (context) => FriendRequestModal(
          userId: inviterId,
          displayName: roomName,
          roomId: roomId,
          onResponse: widget.onInviteHandled, // Trigger the callback to refresh invites
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => GroupInvitationModal(
          groupName: groupName, // Use the defined groupName
          roomId: roomId,
          inviter: inviterId,
          expiration: expiration,
          refreshCallback: widget.onInviteHandled, // Pass the correct callback
        ),
      );
    }
  }
}
