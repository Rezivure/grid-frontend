import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'package:matrix/matrix.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:grid_frontend/widgets/triangle_avatars.dart';

class SessionsSubscreen extends StatefulWidget {
  final ScrollController scrollController;

  SessionsSubscreen({required this.scrollController});

  @override
  _SessionsSubscreenState createState() => _SessionsSubscreenState();
}

class _SessionsSubscreenState extends State<SessionsSubscreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Expanded to allow the ListView to occupy remaining space
        Expanded(
          child: FutureBuilder<List<Room>>(
            future: Provider.of<RoomProvider>(context, listen: false).getInvites(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error loading invites'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No invitations found'));
              } else {
                final invites = snapshot.data!;

                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: invites.length,
                  padding: EdgeInsets.only(top: 8.0),
                  itemBuilder: (context, index) {
                    final room = invites[index];
                    final participants = room.getParticipants();

                    // Extract the inviter
                    String inviterId = participants.isNotEmpty ? participants.last.id : 'Unknown';

                    return Column(
                      children: [
                        ListTile(
                          leading: room.isDirectChat
                              ? RandomAvatar(inviterId, height: 40, width: 40)
                              : TriangleAvatars(
                            userIds: participants
                                .map((m) => m.id.split(":").first.replaceFirst('@', ''))
                                .toList(),
                          ),
                          title: Text(
                            room.name ?? 'Unnamed Session',
                            style: TextStyle(color: colorScheme.onBackground),
                          ),
                          subtitle: Text(
                            'Invited by: $inviterId',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          onTap: () {
                            _handleInviteTap(context, room);
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

  void _handleInviteTap(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Session Invite'),
        content: Text('Would you like to join the session: ${room.name}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await Provider.of<RoomProvider>(context, listen: false).acceptInvitation(room.id);
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error joining the session: $e')),
                );
              }
            },
            child: Text('Join'),
          ),
        ],
      ),
    );
  }
}
