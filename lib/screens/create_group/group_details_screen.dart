import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/providers/room_provider.dart';
import 'package:grid_frontend/utilities/utils.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:grid_frontend/widgets/triangle_avatars.dart'; // Import the TriangleAvatars widget

class GroupDetailsScreen extends StatefulWidget {
  final List<String> selectedUserIds;

  GroupDetailsScreen({required this.selectedUserIds});

  @override
  _GroupDetailsScreenState createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  TextEditingController _groupNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get the current user ID from the roomProvider
    print("HERE");
    print(roomProvider.userId);
    String currentUserId = roomProvider.userId ?? 'unknown_user';

    // Include the creator's user ID in the list
    List<String> allUserIds = [currentUserId, ...widget.selectedUserIds];

    return Scaffold(
      appBar: AppBar(
        title: Text('Group Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Center(
                child: TriangleAvatars(
                  userIds: allUserIds.map((id) => id.split(":").first.replaceFirst('@', '')).toList(),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Members',
                style: theme.textTheme.headlineSmall,
              ),
              ListView.builder(
                shrinkWrap: true, // Make the ListView take only as much space as needed
                physics: NeverScrollableScrollPhysics(), // Disable its own scrolling
                itemCount: allUserIds.length,
                itemBuilder: (context, index) {
                  final userId = allUserIds[index];
                  final username = userId.split(":").first.replaceFirst('@', ''); // Processed username
                  final displayName = '@$username' + (index == 0 ? ' (you)' : ''); // Add "creator" to the first user

                  return ListTile(
                    leading: RandomAvatar(
                      username, // Pass the processed username without '@'
                      height: 40,
                      width: 40,
                    ),
                    title: Text(displayName), // Display the username with '@' and "creator" if applicable
                  );
                },
              ),
              SizedBox(height: 20), // Add spacing between the list and button
              ElevatedButton(
                onPressed: () async {
                  final groupName = _groupNameController.text.trim();
                  if (groupName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Group name cannot be empty')),
                    );
                    return;
                  }

                  await roomProvider.createGroup(
                    groupName,
                    allUserIds,
                    context,
                  );
                  print("GOT HERE");
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Create Group',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary, // Text color in the button
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, // Button color
                  minimumSize: const Size(double.infinity, 50), // Button size
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25), // Rounded corners
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
