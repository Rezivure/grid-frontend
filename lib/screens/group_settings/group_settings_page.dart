import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/widgets/triangle_avatars.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:grid_frontend/screens/friend_settings/friend_settings_page.dart';

class GroupSettingsPage extends StatefulWidget {
  final String roomId;

  GroupSettingsPage({required this.roomId});

  @override
  _GroupSettingsPageState createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  bool _showLocation = true;

  String _extractGroupName(String fullName) {
    final startIndex = fullName.indexOf('(');
    final endIndex = fullName.indexOf(')');
    if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
      return fullName.substring(startIndex + 1, endIndex);
    }
    return fullName;
  }

  void _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Group'),
        content: Text('Are you sure you want to leave the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = Provider.of<Client>(context, listen: false);
        await client.leaveRoom(widget.roomId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You have left the group.')));
        Navigator.of(context).pop(); // Exit the group settings page after leaving the group
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to leave group.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context, listen: false);
    final room = client.getRoomById(widget.roomId);
    final groupName = _extractGroupName(room?.name ?? 'Group');
    final participants = room?.getParticipants() ?? [];
    final isEncrypted = room?.encrypted ?? false;
    final algo = room?.encryptionAlgorithm ?? '';
    final userId = client.userID; // Get the current user's ID

    return Scaffold(
      appBar: AppBar(
        title: Text('Group Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display the larger triangle avatar for the group
            Center(
              child: TriangleAvatars(
                userIds: participants.map((m) => m.id.split(":").first.replaceFirst('@', '')).toList(),
              ),
            ),
            SizedBox(height: 24), // Increase the spacing for better visual separation
            // Display the group name and encryption status
            Center(
              child: Column(
                children: [
                  Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isEncrypted ? 'Encrypted' : 'Unencrypted',
                    style: TextStyle(
                      fontSize: 16,
                      color: isEncrypted ? Colors.green : Colors.red,
                    ),
                  ),
                  if (isEncrypted)
                    Text(
                      algo,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  SizedBox(height: 16),
                  // Show Location toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Share My Location',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      Switch(
                        value: _showLocation,
                        onChanged: (value) {
                          setState(() {
                            _showLocation = value;
                          });
                          // Handle saving the state or triggering any actions related to location sharing
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Display the list of group members
            Text(
              'Members:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final member = participants[index];
                  final membership = member.membership;
                  final power = member.powerLevel;
                  final isAdmin = power == 100;
                  final isInvitee = membership == Membership.invite;
                  final isSelf = member.id == userId; // Check if the member is the current user

                  return ListTile(
                    leading: RandomAvatar(
                      member.id.split(":").first.replaceFirst('@', ''), // Use member ID for avatar generation
                      height: 50, // Slightly larger avatar for the list items
                      width: 50,
                    ),
                    title: Text(
                      '${member.displayName ?? member.id} ${isAdmin ? "(Admin)" : ""}',
                    ),
                    subtitle: Text(
                      isInvitee ? 'Invitee' : 'Member',
                      style: TextStyle(
                        color: isInvitee ? Colors.orange : Colors.black,
                      ),
                    ),
                    onTap: isSelf
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FriendSettingsPage(user: member),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 11),
            // Center the Leave Group Button at the bottom
            Center(
              child: ElevatedButton(
                onPressed: _leaveGroup,
                child: Text('Leave Group'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
