import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:grid_frontend/widgets/custom_search_bar.dart';
import 'package:grid_frontend/widgets/user_profile_modal.dart';
import 'package:grid_frontend/screens/create_group/group_details_screen.dart';
import 'package:grid_frontend/utilities/utils.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:grid_frontend/providers/room_provider.dart'; // Import RoomProvider

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController _searchController = TextEditingController();
  List<Profile> _searchResults = [];
  List<Profile> _selectedUsers = [];
  bool _isLoading = false;

  void _searchUsers() async {
    final client = Provider.of<Client>(context, listen: false);
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await client.searchUserDirectory(_searchController.text, limit: 10);
      setState(() {
        _searchResults = response.results
            .where((profile) => !_selectedUsers.any((selected) => selected.userId == profile.userId))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addUser(Profile profile) {
    setState(() {
      if (!_selectedUsers.contains(profile)) {
        if (_selectedUsers.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only five users can be invited to the group at a time. You can add more members later!')));
        } else {
          _selectedUsers.add(profile);
          _searchResults.remove(profile);
        }
      }
    });
  }

  void _removeUser(Profile profile) {
    setState(() {
      _selectedUsers.remove(profile);
      _searchResults.add(profile);
    });
  }

  void _handleAction() {
    if (_selectedUsers.length == 1) {
      _showAddFriendModal(_selectedUsers.first);
    } else if (_selectedUsers.length > 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupDetailsScreen(
            selectedUserIds: _selectedUsers.map((profile) => profile.userId).toList(), // Pass full user IDs
          ),
        ),
      );
    }
  }

  void _showAddFriendModal(Profile profile) {
    showDialog(
      context: context,
      builder: (context) {
        return UserProfileModal(
          userId: profile.userId,
          displayName: profile.displayName ?? profile.userId,
          onAddFriend: () => _addFriend(profile.userId),
        );
      },
    );
  }

  void _addFriend(String userId) async {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    await roomProvider.createAndInviteUser(userId, context);
    Navigator.pop(context); // Close the modal after sending the invite
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_searchUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Users'),
        actions: _selectedUsers.isNotEmpty
            ? [
          TextButton(
            onPressed: _handleAction,
            child: Text(
              _selectedUsers.length == 1 ? 'Add Friend' : 'Create Group',

            ),
          ),
        ]
            : null,
      ),
      body: Column(
        children: [
          if (_selectedUsers.isNotEmpty)
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = _selectedUsers[index];
                  final username = user.userId.split(":").first.replaceFirst('@', ''); // Process userId for avatar
                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Column(
                          children: [
                            RandomAvatar(
                              username, // Pass processed username to RandomAvatar
                              height: 40,
                              width: 40,
                            ),
                            SizedBox(height: 5),
                            Text(user.displayName ?? user.userId),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeUser(user),
                          child: CircleAvatar(
                            backgroundColor: Colors.black,
                            radius: 10,
                            child: Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          CustomSearchBar(controller: _searchController, hintText: 'Search by @username'),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final profile = _searchResults[index];
                final username = profile.userId.split(":").first.replaceFirst('@', ''); // Process userId for avatar
                return ListTile(
                  title: Text(profile.displayName ?? profile.userId),
                  subtitle: Text(profile.userId),
                  leading: RandomAvatar(
                    username, // Pass processed username to RandomAvatar
                    height: 40,
                    width: 40,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      _selectedUsers.contains(profile) ? Icons.check_circle : Icons.add_circle,
                      color: _selectedUsers.contains(profile) ? Colors.green : Colors.grey,
                    ),
                    onPressed: () => _addUser(profile),
                  ),
                  onTap: () => _addUser(profile),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
