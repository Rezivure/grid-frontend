import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'package:random_avatar/random_avatar.dart';

class FriendSettingsPage extends StatefulWidget {
  final User user;

  FriendSettingsPage({required this.user});

  @override
  _FriendSettingsPageState createState() => _FriendSettingsPageState();
}

class _FriendSettingsPageState extends State<FriendSettingsPage> {
  bool _shareLocation = true;

  void _removeFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Friend'),
        content: Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Should return true for "Remove"
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      final client = roomProvider.client;
      final room = client.rooms.firstWhere((room) =>
          room.getParticipants().any((member) => member.id == widget.user.id && room.membership == Membership.join && room.isDirectChat)
      );
      try {
        // Leave the room
        await client.leaveRoom(room.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You have removed ${widget.user.displayName ?? widget.user.id} as a friend.')));

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to remove friend.')));
      }
      Navigator.of(context).pop(true);
      }
    }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friend Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RandomAvatar(
              widget.user.id.split(":").first.replaceFirst('@', ''), // Generate random avatar based on user ID
              height: 100, // Equivalent to the previous CircleAvatar radius of 50
              width: 100,
            ),
            SizedBox(height: 16),
            Text(
              widget.user.displayName ?? widget.user.id,
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Share Location'),
              value: _shareLocation,
              onChanged: (value) {
                setState(() {
                  _shareLocation = value;
                });
              },
            ),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigate to the map tab to see your friends!')));

              },
              child: Text('Show on Map'),
            ),
            ElevatedButton(
              onPressed: _removeFriend,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.red, // Red text color
              ),
              child: Text('Remove Friend'),
            ),
          ],
        ),
      ),
    );
  }
}
